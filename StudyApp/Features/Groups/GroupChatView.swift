// GroupChatView — chat thread for a single StudyGroup.
// Renders my-vs-others bubble alignment, supports a "오늘 기록 공유" attachment,
// auto-marks newly visible messages as read so the unread badge stays honest.

import SwiftUI
import SwiftData
import StudyCore

struct GroupChatView: View {
    let group: StudyGroupModel
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]

    @Query(sort: \ChatMessageModel.sentAt)
    private var allMessages: [ChatMessageModel]

    @Query private var blockedFriends: [FriendProfileModel]

    @State private var draft: String = ""
    @State private var showingShareSheet = false
    @State private var inlineError: String?
    @FocusState private var inputFocused: Bool

    private var meCode: String { mes.first?.friendCode ?? "" }

    private var groupMessages: [ChatMessageModel] {
        let gid = group.id
        let blockedCodes = Set(blockedFriends.filter { $0.isBlocked }.map { $0.friendCode })
        return allMessages.filter { msg in
            msg.groupId == gid
                && !msg.isReported
                && !blockedCodes.contains(msg.senderFriendCode)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if let inlineError {
                Text(inlineError)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.error)
                    .padding(.horizontal, DT.Spacing.lg)
                    .padding(.vertical, DT.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DT.Color.error.opacity(0.10))
            }
            inputBar
        }
        .background(DT.Color.surface.ignoresSafeArea())
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("그룹 코드 복사: \(group.code)") {
                        UIPasteboard.general.string = group.code
                    }
                    Button(role: .destructive) {
                        SocialService.leaveGroup(group, in: context)
                    } label: {
                        Text("그룹 나가기")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareTodayRecordSheet(group: group)
        }
        .task(id: group.id) { markRead() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DT.Spacing.sm) {
                    ForEach(groupMessages) { msg in
                        MessageBubble(
                            message: msg,
                            isMine: msg.senderFriendCode == meCode
                        )
                        .id(msg.id)
                    }
                }
                .padding(.horizontal, DT.Spacing.lg)
                .padding(.vertical, DT.Spacing.lg)
            }
            .onChange(of: groupMessages.last?.id) { _, newValue in
                guard let newValue else { return }
                withAnimation { proxy.scrollTo(newValue, anchor: .bottom) }
            }
            .onAppear {
                if let last = groupMessages.last?.id {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: DT.Spacing.sm) {
            Button(action: { showingShareSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DT.Color.primary)
            }
            .buttonStyle(.plain)

            TextField("메시지", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .lineLimit(1...4)
                .onChange(of: draft) { _, _ in
                    if inlineError != nil { inlineError = nil }
                }

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(
                        draft.trimmingCharacters(in: .whitespaces).isEmpty
                            ? DT.Color.textSecondary : DT.Color.primary
                    ))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, DT.Spacing.md)
        .padding(.vertical, DT.Spacing.sm)
        .background(DT.Color.background)
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let result = SocialService.sendChat(text: trimmed, to: group, in: context)
        switch result {
            case .sent:
                draft = ""
                inlineError = nil
            case .empty:
                inlineError = "내용을 입력해주세요."
            case .blockedByFilter(let reason):
                inlineError = reason
            case .saveFailed:
                inlineError = "메시지 저장에 실패했어요. 잠시 후 다시 시도해주세요."
        }
    }

    private func markRead() {
        var changed = false
        for msg in groupMessages where !msg.anyoneRead && msg.senderFriendCode != meCode {
            msg.anyoneRead = true
            changed = true
        }
        if changed {
            Persistence.save({ try context.save() }, context: "chat.markRead")
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessageModel
    let isMine: Bool
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(message.senderFriendCode)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DT.Color.textSecondary)
                }
                if let summary = message.attachedRecordSummary {
                    RecordAttachmentCard(
                        summary: summary,
                        kind: message.attachedKind,
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
                Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(DT.Color.textSecondary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
        .contextMenu {
            if !isMine {
                Button(role: .destructive) {
                    SocialService.reportMessage(message, in: context)
                } label: {
                    Label("신고", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }
}

private struct RecordAttachmentCard: View {
    let summary: String
    let kind: AttachedKind?
    let isMine: Bool

    var body: some View {
        HStack(spacing: DT.Spacing.sm) {
            Image(systemName: kind == .runSession ? "figure.run" : "book.fill")
                .foregroundStyle(isMine ? .white : DT.Color.primary)
            Text(summary)
                .font(DT.Typography.caption)
                .foregroundStyle(isMine ? .white : DT.Color.textPrimary)
        }
        .padding(.horizontal, DT.Spacing.md)
        .padding(.vertical, DT.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMine
                      ? DT.Color.primaryDark
                      : DT.Color.primary.opacity(0.10))
        )
    }
}

private struct ShareTodayRecordSheet: View {
    let group: StudyGroupModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let calendar = PlannerCalendar(cutoffHour: 3)

    @Query private var studySessions: [StudySessionModel]
    @Query private var runSessions: [RunSessionModel]
    @Query private var subjects: [SubjectModel]

    @State private var errorMessage: String?

    private var today: Int { calendar.plannerDay(for: Date()) }

    private var todayStudy: Int {
        studySessions.filter { $0.plannerDay == today }.reduce(0) { $0 + $1.totalSeconds }
    }
    private var todayRunMeters: Double {
        runSessions.filter { $0.plannerDay == today }.reduce(0.0) { $0 + $1.distanceMeters }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("오늘 기록") {
                    if todayStudy > 0 {
                        Button("📚 오늘 순공 \(todayStudy / 60)분 공유") {
                            share(kind: .studySession,
                                  summary: "오늘 순공 \(todayStudy / 60)분")
                        }
                    }
                    if todayRunMeters > 0 {
                        let km = String(format: "%.2f", todayRunMeters / 1000)
                        Button("🏃 오늘 러닝 \(km)km 공유") {
                            share(kind: .runSession,
                                  summary: "오늘 러닝 \(km)km")
                        }
                    }
                    if todayStudy == 0 && todayRunMeters == 0 {
                        Text("아직 오늘 기록이 없어요").foregroundStyle(DT.Color.textSecondary)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(DT.Typography.caption)
                            .foregroundStyle(DT.Color.error)
                    }
                }
            }
            .navigationTitle("기록 공유")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() } }
            }
        }
    }

    private func share(kind: AttachedKind, summary: String) {
        let result = SocialService.sendChat(
            text: "",
            to: group,
            attachedKind: kind,
            attachedRecordSummary: summary,
            in: context
        )
        switch result {
            case .sent:
                dismiss()
            case .empty:
                errorMessage = "공유할 내용이 비어 있어요."
            case .blockedByFilter(let reason):
                errorMessage = reason
            case .saveFailed:
                errorMessage = "공유에 실패했어요. 잠시 후 다시 시도해주세요."
        }
    }
}
