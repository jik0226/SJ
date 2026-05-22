// ChatInboxView — the chat tab's home: a list of recent conversations.
//
// Personal DMs surface first (the common case), study groups below. Each row
// shows the counterpart name, last message preview, time, and unread badge —
// the inbox layout users expect from any messaging app. New chats start by
// picking a friend; "+" also exposes friend-add and group create/join.

import SwiftUI
import SwiftData
import StudyCore

struct ChatInboxView: View {
    @Environment(\.modelContext) private var context
    @State private var server = ServerMode.shared

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]
    @Query private var allProfiles: [FriendProfileModel]
    @Query(sort: \StudyGroupModel.createdAt, order: .reverse)
    private var allGroups: [StudyGroupModel]
    @Query(sort: \ChatMessageModel.sentAt)
    private var allMessages: [ChatMessageModel]

    @State private var navigateToGroup: StudyGroupModel?
    @State private var showingNewChat = false
    @State private var showingAddFriend = false
    @State private var showingCreateGroup = false
    @State private var showingJoinGroup = false
    @State private var openingError: String?

    private var meCode: String { mes.first?.friendCode ?? "" }

    private var myGroups: [StudyGroupModel] {
        guard !meCode.isEmpty else { return [] }
        return allGroups.filter { $0.memberCodes.contains(meCode) }
    }

    private var dmThreads: [StudyGroupModel] {
        myGroups
            .filter { $0.code.hasPrefix(SocialService.directMessageCodePrefix) }
            .sorted { lastSentAt($0) > lastSentAt($1) }
    }

    private var groupThreads: [StudyGroupModel] {
        myGroups
            .filter { !$0.code.hasPrefix(SocialService.directMessageCodePrefix) }
            .sorted { lastSentAt($0) > lastSentAt($1) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dmThreads.isEmpty && groupThreads.isEmpty {
                    // No threads yet: show offline-specific copy when relevant,
                    // otherwise the standard "add a friend" empty state.
                    if server.isOnline { emptyState } else { offlineState }
                } else {
                    // Offline still shows existing conversations (read-only) —
                    // only starting/sending is gated. A slim banner explains.
                    threadList
                }
            }
            .background(DT.Color.surface.ignoresSafeArea())
            .navigationTitle("채팅")
            .toolbar { toolbarMenu }
            .navigationDestination(item: $navigateToGroup) { group in
                GroupChatView(group: group)
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatSheet(friends: addableFriends) { friend in
                    showingNewChat = false
                    openDM(with: friend)
                }
            }
            .sheet(isPresented: $showingAddFriend) { AddFriendSheet() }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupSheet(onCreated: { navigateToGroup = $0 })
            }
            .sheet(isPresented: $showingJoinGroup) {
                JoinGroupSheet(onJoined: { navigateToGroup = $0 })
            }
            .alert(
                "대화를 열 수 없어요",
                isPresented: Binding(get: { openingError != nil }, set: { if !$0 { openingError = nil } }),
                actions: { Button("확인", role: .cancel) {} },
                message: { Text(openingError ?? "") }
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showingNewChat = true } label: {
                    Label("새 대화", systemImage: "square.and.pencil")
                }
                Button { showingAddFriend = true } label: {
                    Label("친구 추가", systemImage: "person.badge.plus")
                }
                Divider()
                Button { showingCreateGroup = true } label: {
                    Label("새 그룹", systemImage: "person.3")
                }
                Button { showingJoinGroup = true } label: {
                    Label("그룹 코드로 참여", systemImage: "number")
                }
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .disabled(!server.isOnline)
        }
    }

    // MARK: - Lists

    private var threadList: some View {
        List {
            if !server.isOnline {
                Section {
                    HStack(spacing: DT.Spacing.sm) {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(DT.Color.warning)
                        Text("오프라인 — 지난 대화는 볼 수 있고, 새 메시지는 연결 후 보낼 수 있어요.")
                            .font(DT.Typography.caption)
                            .foregroundStyle(DT.Color.textSecondary)
                    }
                }
            }
            if !dmThreads.isEmpty {
                Section("개인 대화") {
                    ForEach(dmThreads) { thread in
                        Button { navigateToGroup = thread } label: {
                            ChatThreadRow(
                                title: dmTitle(thread),
                                preview: preview(thread),
                                time: lastSentAt(thread),
                                unread: unreadCount(thread),
                                isGroup: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !groupThreads.isEmpty {
                Section("그룹") {
                    ForEach(groupThreads) { thread in
                        Button { navigateToGroup = thread } label: {
                            ChatThreadRow(
                                title: thread.name,
                                preview: preview(thread),
                                time: lastSentAt(thread),
                                unread: unreadCount(thread),
                                isGroup: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DT.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(DT.Color.textSecondary)
            Text("아직 대화가 없어요")
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textPrimary)
            Text("친구를 추가하고 첫 메시지를 보내보세요.")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Button { showingAddFriend = true } label: {
                Label("친구 추가", systemImage: "person.badge.plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DT.Spacing.xl)
                    .padding(.vertical, DT.Spacing.md)
                    .background(Capsule().fill(DT.Color.primary))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var offlineState: some View {
        VStack(spacing: DT.Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(DT.Color.warning)
            Text("지금은 오프라인이에요")
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textPrimary)
            Text("채팅은 서버 연결 후 사용할 수 있어요.\n타이머·플래너는 평소처럼 동작합니다.")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var addableFriends: [FriendProfileModel] {
        allProfiles.filter { !$0.isMe && !$0.isBlocked }
    }

    private func messages(in thread: StudyGroupModel) -> [ChatMessageModel] {
        allMessages.filter { $0.groupId == thread.id && !$0.isReported }
    }

    private func lastSentAt(_ thread: StudyGroupModel) -> Date {
        messages(in: thread).map(\.sentAt).max() ?? thread.createdAt
    }

    private func preview(_ thread: StudyGroupModel) -> String {
        guard let last = messages(in: thread).sorted(by: { $0.sentAt > $1.sentAt }).first else {
            return "아직 대화가 없어요"
        }
        if let summary = last.attachedRecordSummary, last.text.isEmpty {
            return "📎 \(summary)"
        }
        return last.text
    }

    private func unreadCount(_ thread: StudyGroupModel) -> Int {
        messages(in: thread).filter { !$0.anyoneRead && $0.senderFriendCode != meCode }.count
    }

    private func dmTitle(_ thread: StudyGroupModel) -> String {
        let otherCode = thread.memberCodes.first { $0 != meCode }
        if let otherCode,
           let friend = allProfiles.first(where: { $0.friendCode == otherCode }),
           !friend.nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            return friend.nickname
        }
        return thread.name
    }

    private func openDM(with friend: FriendProfileModel) {
        Task {
            do {
                let group = try await SocialService.ensureDirectMessageGroup(with: friend, in: context)
                navigateToGroup = group
            } catch SocialError.serverPublishFailed {
                openingError = "서버 연결에 문제가 있어요. 잠시 후 다시 시도해주세요."
            } catch {
                openingError = "대화방을 열 수 없어요. 잠시 후 다시 시도해주세요."
            }
        }
    }
}

/// One conversation row. Mirrors the standard messaging-app row layout.
private struct ChatThreadRow: View {
    let title: String
    let preview: String
    let time: Date
    let unread: Int
    let isGroup: Bool

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: isGroup ? "person.3.fill" : "person.crop.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(DT.Color.primary))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                    .lineLimit(1)
                Text(preview)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(time.formatted(.relative(presentation: .numeric)))
                    .font(.system(size: 10))
                    .foregroundStyle(DT.Color.textSecondary)
                if unread > 0 {
                    Text("\(unread)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(DT.Color.error))
                }
            }
        }
        .padding(.vertical, 4)
        // Whole row (including the empty gap before the timestamp) is the tap
        // target — standard messaging-app expectation.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Picks a friend to start (or resume) a 1:1 chat with.
private struct NewChatSheet: View {
    let friends: [FriendProfileModel]
    let onSelect: (FriendProfileModel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if friends.isEmpty {
                    VStack(spacing: DT.Spacing.sm) {
                        Image(systemName: "person.2")
                            .font(.system(size: 36))
                            .foregroundStyle(DT.Color.textSecondary)
                        Text("먼저 친구를 추가해주세요")
                            .font(DT.Typography.body)
                            .foregroundStyle(DT.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { friend in
                        Button { onSelect(friend) } label: {
                            HStack(spacing: DT.Spacing.md) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(DT.Color.primary)
                                Text(friend.nickname)
                                    .font(DT.Typography.body)
                                    .foregroundStyle(DT.Color.textPrimary)
                                Spacer()
                                Image(systemName: "bubble.left.fill")
                                    .foregroundStyle(DT.Color.primary.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("새 대화")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() } }
            }
        }
    }
}
