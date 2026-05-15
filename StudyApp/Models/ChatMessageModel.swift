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

    /// Outbound delivery state — `sending` while the Firestore publish is
    /// in-flight, `sent` once it lands, `failed` on permission/network
    /// errors. Inbound (mirrored) messages are always `.sent`.
    /// Stored as a raw String so SwiftData migration stays cheap.
    var deliveryStateRaw: String

    init(
        id: UUID = UUID(),
        groupId: UUID,
        senderFriendCode: String,
        text: String,
        sentAt: Date = Date(),
        isReported: Bool = false,
        attachedRecordSummary: String? = nil,
        attachedKind: AttachedKind? = nil,
        anyoneRead: Bool = false,
        deliveryState: DeliveryState = .sent
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
        self.deliveryStateRaw = deliveryState.rawValue
    }

    var deliveryState: DeliveryState {
        get { DeliveryState(rawValue: deliveryStateRaw) ?? .sent }
        set { deliveryStateRaw = newValue.rawValue }
    }

    var attachedKind: AttachedKind? {
        AttachedKind(rawValue: attachedKindRaw ?? "")
    }
}

enum AttachedKind: String, Codable, CaseIterable, Sendable {
    case studySession
    case runSession
}

enum DeliveryState: String, Codable, CaseIterable, Sendable {
    case sending
    case sent
    case failed
}
