// GroupChatView — chat thread for a single StudyGroup.
// Renders my-vs-others bubble alignment, supports a "오늘 기록 공유" attachment,
// auto-marks newly visible messages as read so the unread badge stays honest.
//
// The bubble + attachment-preview components live in GroupChatView+Bubble.swift
// and the share sheet in GroupChatView+Share.swift.

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

    /// All local profiles (friends + me). Used both for the blocked-sender
    /// filter and for resolving a friendCode → nickname in chat bubbles.
    @Query private var allProfiles: [FriendProfileModel]

    @State private var draft: String = ""
    @State private var showingShareSheet = false
    @State private var inlineError: String?
    @State private var showingLeaveConfirm = false
    @FocusState private var inputFocused: Bool

    private var meCode: String { mes.first?.friendCode ?? "" }

    /// friendCode → display nickname. Falls back to the code only for members
    /// not in the local friend list (e.g. a group member you haven't added).
    private func displayName(for code: String) -> String {
        if code == meCode { return mes.first?.nickname ?? "나" }
        if let match = allProfiles.first(where: { $0.friendCode == code }),
           !match.nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            return match.nickname
        }
        return code
    }

    /// 1:1 DMs are represented as two-member groups whose code starts with
    /// the reserved DM prefix. We hide group-only affordances (join code,
    /// "그룹 나가기") and surface a friend-info entry instead.
    private var isDirectMessage: Bool {
        group.code.hasPrefix(SocialService.directMessageCodePrefix)
            && group.memberCodes.count == 2
    }

    private var dmFriend: FriendProfileModel? {
        guard isDirectMessage else { return nil }
        let otherCode = group.memberCodes.first { $0 != meCode }
        guard let otherCode else { return nil }
        let predicate = #Predicate<FriendProfileModel> { $0.friendCode == otherCode }
        return try? context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    private var groupMessages: [ChatMessageModel] {
        let gid = group.id
        let blockedCodes = Set(allProfiles.filter { $0.isBlocked }.map { $0.friendCode })
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
                    if isDirectMessage {
                        if let friend = dmFriend {
                            NavigationLink {
                                FriendDetailView(friend: friend)
                            } label: {
                                Text("친구 정보")
                            }
                        }
                    } else {
                        Button("그룹 코드 복사: \(group.code)") {
                            UIPasteboard.general.string = group.code
                        }
                    }
                    Button(role: .destructive) {
                        showingLeaveConfirm = true
                    } label: {
                        Text(isDirectMessage ? "대화 나가기" : "그룹 나가기")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareTodayRecordSheet(group: group)
        }
        .confirmationDialog(
            isDirectMessage ? "이 대화를 나갈까요?" : "그룹에서 나갈까요?",
            isPresented: $showingLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("나가기", role: .destructive) {
                SocialService.leaveGroup(group, in: context)
            }
            Button("취소", role: .cancel) {}
        } message: {
            if isDirectMessage {
                Text("대화 기록이 내 폰에서 사라집니다. 친구가 다시 메시지를 보내면 같은 대화방이 자동으로 열립니다.")
            } else {
                Text("나간 뒤 다시 참여하려면 그룹 코드(\(group.code))가 필요해요. 내가 마지막 멤버라면 그룹이 함께 사라집니다.")
            }
        }
        .task(id: group.id) {
            markRead()
            // Backfill our membership (uid + code) without touching name/code —
            // the rules accept this as a member edit or a room self-join, so a
            // legacy group we're in heals its memberUids the moment we open it.
            // A full publish would clobber a freshly-joined room's placeholder
            // name onto the server, so we only add ourselves here.
            let gid = group.id
            let isRoom = !group.code.hasPrefix(SocialService.directMessageCodePrefix)
            if let myUid = AuthBootstrap.shared.currentUID {
                try? await FirestoreSyncService.shared.joinGroupAddSelf(
                    groupId: gid, myUid: myUid, myCode: meCode
                )
                // Re-register a room's join code in case it predates groupCodes.
                if isRoom {
                    try? await FirestoreSyncService.shared.publishGroupCode(
                        code: group.code, gid: gid.uuidString
                    )
                }
            }
            // Firestore listener: new messages arriving from other devices
            // get mirrored into SwiftData by FirestoreSyncService. The task
            // cancellation tears the listener down when the user leaves the
            // chat thread so we don't leak network sockets per group.
            FirestoreSyncService.shared.startListening(group: group, context: context)
        }
        .onDisappear {
            FirestoreSyncService.shared.stopListening(group: group)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DT.Spacing.sm) {
                    ForEach(groupMessages) { msg in
                        MessageBubble(
                            message: msg,
                            isMine: msg.senderFriendCode == meCode,
                            senderName: displayName(for: msg.senderFriendCode)
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
                // The user is actively viewing the thread, so any message
                // that lands while the screen is open should be marked read
                // immediately — otherwise the unread badge lingers on the
                // group row even though they're looking right at the message.
                markRead()
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
        // Optimistic: clear the input the moment we kick off the send. The
        // bubble will show "전송 중…" until Firestore confirms, and flip to
        // "전송 실패 — 다시 시도" if publish errors. This keeps the input
        // responsive while still surfacing the real delivery status.
        let captured = trimmed
        draft = ""
        inlineError = nil
        Task {
            let result = await SocialService.sendChat(
                text: captured, to: group, in: context
            )
            switch result {
                case .sent, .serverPublishFailed:
                    // Bubble itself shows the failed state + retry option.
                    break
                case .empty:
                    draft = captured
                    inlineError = "내용을 입력해주세요."
                case .blockedByFilter(let reason):
                    draft = captured
                    inlineError = reason
                case .saveFailed:
                    draft = captured
                    inlineError = "메시지 저장에 실패했어요. 잠시 후 다시 시도해주세요."
            }
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
