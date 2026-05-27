// GroupChatView+Bubble — the message-bubble row and its rich attachment
// previews (planner mini grid, ocean snapshot). Split out of GroupChatView so
// each file stays focused; these components don't touch GroupChatView's state.

import SwiftUI
import SwiftData
import StudyCore

struct MessageBubble: View {
    let message: ChatMessageModel
    let isMine: Bool
    var senderName: String = ""
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(senderName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DT.Color.textSecondary)
                }
                if let summary = message.attachedRecordSummary {
                    RecordAttachmentCard(
                        summary: summary,
                        kind: message.attachedKind,
                        payloadJSON: message.attachedPayloadJSON,
                        isMine: isMine
                    )
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(DT.Typography.body)
                        .foregroundStyle(isMine ? .white : DT.Color.textPrimary)
                        .padding(.horizontal, DT.Spacing.md)
                        .padding(.vertical, DT.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isMine ? DT.Color.primary : DT.Color.background)
                        )
                }
                HStack(spacing: 4) {
                    Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(DT.Color.textSecondary)
                    if isMine { deliveryIndicator }
                }
            }
            if !isMine { Spacer(minLength: 40) }
        }
        .contextMenu {
            if isMine, message.deliveryState == .failed {
                Button {
                    Task { await SocialService.retrySend(message, in: context) }
                } label: {
                    Label("다시 보내기", systemImage: "arrow.clockwise")
                }
            }
            if !isMine {
                Button(role: .destructive) {
                    SocialService.reportMessage(message, in: context)
                } label: {
                    Label("신고", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    /// Tiny send-state badge next to my outgoing bubbles. Inbound messages
    /// stay `.sent` so this only ever appears on my own side. The `.failed`
    /// badge is the tap target itself — earlier the user had to long-press
    /// to find "다시 보내기", but the label already looks tappable so we
    /// promoted it to the actual action.
    @ViewBuilder
    private var deliveryIndicator: some View {
        switch message.deliveryState {
            case .sending:
                Image(systemName: "clock")
                    .font(.system(size: 9))
                    .foregroundStyle(DT.Color.textSecondary)
            case .failed:
                Button {
                    Task { await SocialService.retrySend(message, in: context) }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                        Text("실패 - 다시 시도")
                            .font(.system(size: 10, weight: .medium))
                            .underline()
                    }
                    .foregroundStyle(DT.Color.error)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("메시지 다시 보내기")
            case .sent:
                EmptyView()
        }
    }
}

struct RecordAttachmentCard: View {
    let summary: String
    let kind: AttachedKind?
    var payloadJSON: String? = nil
    let isMine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.xs) {
            richPreview
            HStack(spacing: DT.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(isMine ? .white : DT.Color.primary)
                Text(summary)
                    .font(DT.Typography.caption)
                    .foregroundStyle(isMine ? .white : DT.Color.textPrimary)
            }
        }
        .padding(.horizontal, DT.Spacing.md)
        .padding(.vertical, DT.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMine ? DT.Color.primaryDark : DT.Color.primary.opacity(0.10))
        )
    }

    private var icon: String {
        switch kind {
            case .runSession: return "figure.run"
            case .plannerDay: return "calendar"
            case .oceanSnapshot: return "water.waves"
            case .streak: return "flame.fill"
            default: return "book.fill"
        }
    }

    @ViewBuilder
    private var richPreview: some View {
        switch kind {
            case .plannerDay:
                if let planner = decode(AttachmentPayload.Planner.self) {
                    PlannerMiniGrid(slots: planner.slots)
                }
            case .oceanSnapshot:
                if let ocean = decode(AttachmentPayload.Ocean.self) {
                    OceanMiniPreview(ocean: ocean)
                }
            case .streak:
                if let streak = decode(AttachmentPayload.Streak.self) {
                    Text("🔥 \(streak.days)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(isMine ? .white : DT.Color.primary)
                }
            default:
                EmptyView()
        }
    }

    private func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let json = payloadJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// Compact color grid mirroring the planner blocks the sender filled today.
struct PlannerMiniGrid: View {
    let slots: [String: String]

    private let columns = Array(repeating: GridItem(.fixed(8), spacing: 2), count: 12)

    var body: some View {
        // Show the 12 most-recent filled slots as colored squares so the
        // card stays small but recognizably "planner-shaped".
        let entries = slots.sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }.prefix(24)
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entries), id: \.key) { _, hex in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hexString: hex) ?? DT.Color.primary)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: 132)
    }
}

/// Tiny static ocean reconstructed from the sender's seed + nutrients.
struct OceanMiniPreview: View {
    let ocean: AttachmentPayload.Ocean

    var body: some View {
        PlantCanvasView(
            parameters: PlantFormula.parameters(
                seed: UInt64(bitPattern: Int64(ocean.seed)),
                nutrients: PlantNutrients(
                    studyMinutes: ocean.study, workoutMinutes: ocean.workout,
                    sequenceHash: ocean.sequenceHash ?? 0
                )
            ),
            sway: 0
        )
        .frame(width: 132, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
