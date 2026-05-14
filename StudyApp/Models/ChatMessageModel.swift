// ChatMessageModel — message in a StudyGroup chat thread.
// `attachedRecordSummary` carries an optional pre-rendered description when
// the sender shares a study/run record so receivers don't need to fetch the
// original session row.

import Foundation
import SwiftData

@Model
final class ChatMessageModel {
    @Attribute(.unique) var id: UUID
    var groupId: UUID
    var senderFriendCode: String
    var text: String
    var sentAt: Date
    var isReported: Bool
    /// Sender-side rendered summary of an attached record (e.g. "오늘 수학 1시간 30분").
    /// nil = plain chat message.
    var attachedRecordSummary: String?
    /// Categorises the attachment when present.
    var attachedKindRaw: String?
    /// Per-receiver read flag isn't tracked separately yet; PoC keeps a single
    /// "anyone has read this" bit so badges work without a full receipts table.
    var anyoneRead: Bool

    init(
        id: UUID = UUID(),
        groupId: UUID,
        senderFriendCode: String,
        text: String,
        sentAt: Date = Date(),
        isReported: Bool = false,
        attachedRecordSummary: String? = nil,
        attachedKind: AttachedKind? = nil,
        anyoneRead: Bool = false
    ) {
        self.id = id
        self.groupId = groupId
        self.senderFriendCode = senderFriendCode
        self.text = text
        self.sentAt = sentAt
        self.isReported = isReported
        self.attachedRecordSummary = attachedRecordSummary
        self.attachedKindRaw = attachedKind?.rawValue
        self.anyoneRead = anyoneRead
    }

    var attachedKind: AttachedKind? {
        AttachedKind(rawValue: attachedKindRaw ?? "")
    }
}

enum AttachedKind: String, Codable, CaseIterable, Sendable {
    case studySession
    case runSession
}
