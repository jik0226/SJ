// SocialService+Chat — send/retry/report chat messages. Sends are optimistic:
// the local row saves as `.sending`, awaits the Firestore publish, then flips
// to `.sent` or `.failed` so the UI can offer retry without losing the text.

import Foundation
import SwiftData
import StudyCore

extension SocialService {
    @discardableResult
    static func sendChat(
        text: String,
        to group: StudyGroupModel,
        attachedKind: AttachedKind? = nil,
        attachedRecordSummary: String? = nil,
        attachedPayloadJSON: String? = nil,
        in context: ModelContext
    ) async -> ChatSendResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachedRecordSummary != nil else {
            return .empty
        }
        if case .blocked(let reason) = ProfanityFilter.check(trimmed) {
            return .blockedByFilter(reason: reason)
        }
        let me = me(in: context)

        // PLAN §9 minor safety: 14세 미만 사용자에게는 메시지 길이를 더 짧게
        // 잡고 (200자, anonymous-style 변종 금지 부담 대신 단순 cap), 욕설 외에도
        // 외부 링크 차단을 추가한다.
        let effectiveMaxLength = me.isMinor ? 200 : 500
        let capped = String(trimmed.prefix(effectiveMaxLength))
        if me.isMinor, containsURL(capped) {
            return .blockedByFilter(reason: "만 14세 미만 사용자는 외부 링크를 공유할 수 없어요.")
        }

        let msg = ChatMessageModel(
            groupId: group.id,
            senderFriendCode: me.friendCode,
            text: capped,
            attachedRecordSummary: attachedRecordSummary,
            attachedKind: attachedKind,
            attachedPayloadJSON: attachedPayloadJSON,
            deliveryState: .sending
        )
        context.insert(msg)
        guard Persistence.save({ try context.save() }, context: "chat.send") != nil else {
            return .saveFailed
        }
        // Await the Firestore publish so the bubble flips from "sending" to
        // "sent" only after the server actually has it. Network/permission
        // failures land the row in `.failed` so the UI can offer retry.
        do {
            try await FirestoreSyncService.shared.publishMessage(msg)
            msg.deliveryState = .sent
            Persistence.save({ try context.save() }, context: "chat.send.delivered")
            return .sent
        } catch {
            msg.deliveryState = .failed
            Persistence.save({ try context.save() }, context: "chat.send.failed")
            Persistence.log(error, context: "firestore.publishMessage.send")
            return .serverPublishFailed
        }
    }

    /// Re-attempts publish for a message previously stuck in `.failed`.
    /// Returns `.sent` when delivery now succeeds, `.serverPublishFailed`
    /// otherwise. Idempotent — Firestore setData(merge:) safely re-writes.
    @discardableResult
    static func retrySend(
        _ msg: ChatMessageModel, in context: ModelContext
    ) async -> ChatSendResult {
        msg.deliveryState = .sending
        Persistence.save({ try context.save() }, context: "chat.retry.start")
        do {
            try await FirestoreSyncService.shared.publishMessage(msg)
            msg.deliveryState = .sent
            Persistence.save({ try context.save() }, context: "chat.retry.sent")
            return .sent
        } catch {
            msg.deliveryState = .failed
            Persistence.save({ try context.save() }, context: "chat.retry.failed")
            Persistence.log(error, context: "firestore.publishMessage.retry")
            return .serverPublishFailed
        }
    }

    static func reportMessage(_ msg: ChatMessageModel, in context: ModelContext) {
        msg.isReported = true
        Persistence.save({ try context.save() }, context: "chat.report")
        // Deliver the report to the server so it actually reaches the operator
        // (Apple UGC guideline 1.2); the local flag alone is invisible to us.
        // Capture value types up front — ChatMessageModel isn't Sendable, so it
        // can't cross into the @MainActor hop.
        let id = msg.id.uuidString
        let gid = msg.groupId.uuidString
        let code = msg.senderFriendCode
        let text = msg.text
        let summary = msg.attachedRecordSummary
        Task { @MainActor in
            FirestoreSyncService.shared.publishReport(
                messageID: id, groupID: gid,
                senderFriendCode: code, text: text, summary: summary
            )
        }
    }

    enum ChatSendResult: Equatable {
        case sent
        case empty
        case blockedByFilter(reason: String)
        case saveFailed
        /// Local saved as `.sending`/`.failed` but Firestore publish errored.
        /// UI keeps the bubble and offers retry instead of losing the text.
        case serverPublishFailed
    }
}
