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
    /// JSON payload for rich attachments (planner slot colors, ocean seed +
    /// nutrients, streak count). Decoded by RecordAttachmentCard per kind.
    var attachedPayloadJSON: String?
    /// Per-receiver read flag isn't tracked separately yet; PoC keeps a single
    /// "anyone has read this" bit so badges work without a full receipts table.
    var anyoneRead: Bool

    /// Outbound delivery state — `sending` while the Firestore publish is
    /// in-flight, `sent` once it lands, `failed` on permission/network
    /// errors. Inbound (mirrored) messages are always `.sent`.
    /// Stored as a raw String. The stored default is REQUIRED for SwiftData
    /// lightweight migration: without it, adding this column to an existing
    /// store fails (the previous cause of the data-wipe fallback).
    var deliveryStateRaw: String = DeliveryState.sent.rawValue

    init(
        id: UUID = UUID(),
        groupId: UUID,
        senderFriendCode: String,
        text: String,
        sentAt: Date = Date(),
        isReported: Bool = false,
        attachedRecordSummary: String? = nil,
        attachedKind: AttachedKind? = nil,
        attachedPayloadJSON: String? = nil,
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
        self.attachedPayloadJSON = attachedPayloadJSON
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
    case plannerDay
    case oceanSnapshot
    case streak
}

// AttachmentPayload moved to StudyCore (AttachmentPayload.swift) so the
// JSON round-trip is unit-testable. AttachedKind stays here because it's
// tied to this SwiftData @Model.

enum DeliveryState: String, Codable, CaseIterable, Sendable {
    case sending
    case sent
    case failed
}
