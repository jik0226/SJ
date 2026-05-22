// RootView — top-level tab container.
// Five primary tabs; "더보기" exposes Subjects + Friends + Cellog so the bottom
// bar doesn't drift past iOS's 5-tab recommendation.

import SwiftUI
import SwiftData

enum RootTab: String, Hashable {
    case home, timer, planner, chat, more
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var selection: RootTab = RootView.initialTab()
    @State private var didFirstSync = false

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]
    @Query(filter: #Predicate<ChatMessageModel> { !$0.anyoneRead && !$0.isReported })
    private var unreadChats: [ChatMessageModel]
    @Query private var allGroups: [StudyGroupModel]

    /// Unread messages across every group/DM I'm a member of, excluding my
    /// own. Drives the badge on the 채팅 tab.
    private var unreadCount: Int {
        guard let me = mes.first else { return 0 }
        let myGroupIds = Set(allGroups.filter { $0.memberCodes.contains(me.friendCode) }.map(\.id))
        return unreadChats.filter {
            myGroupIds.contains($0.groupId) && $0.senderFriendCode != me.friendCode
        }.count
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(selection: $selection)
                .tag(RootTab.home)
                .tabItem { Label("홈", systemImage: "house.fill") }
            TimerView()
                .tag(RootTab.timer)
                .tabItem { Label("타이머", systemImage: "timer") }
            PlannerView()
                .tag(RootTab.planner)
                .tabItem { Label("플래너", systemImage: "calendar") }
            ChatInboxView()
                .tag(RootTab.chat)
                .tabItem { Label("채팅", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(unreadCount)
            MoreMenuView()
                .tag(RootTab.more)
                .tabItem { Label("더보기", systemImage: "ellipsis.circle.fill") }
        }
        .tint(DT.Color.primary)
        .onAppear {
            if appState.modelContext == nil {
                appState.modelContext = modelContext
            }
            guard !didFirstSync else { return }
            didFirstSync = true
            Task {
                // Wait for anon auth to settle so private/* reads have a UID.
                await AuthBootstrap.shared.signInIfNeeded()
                await FirestoreSyncService.shared.pullPrivateSnapshot(into: modelContext)
                // Subscribe to the friends subcollection so the other side
                // of a mutual friendship pushes into our local SwiftData
                // automatically when they add us.
                FirestoreSyncService.shared.startListeningFriends(context: modelContext)
                // Inbox: watch every group I'm a member of (incl. DMs others
                // started) so incoming chats arrive as unread threads without
                // me opening them first.
                let myCode = SocialService.me(in: modelContext).friendCode
                FirestoreSyncService.shared.startListeningMyGroups(
                    myFriendCode: myCode, context: modelContext
                )
                // Re-publish summary after pull so the public doc reflects any
                // remote data that arrived first on this device.
                appState.publishPublicSnapshot(context: modelContext)
            }
        }
    }

    private static func initialTab() -> RootTab {
        let args = ProcessInfo.processInfo.arguments
        if let arg = args.first(where: { $0.hasPrefix("--start-tab=") }) {
            let raw = String(arg.dropFirst("--start-tab=".count))
            return RootTab(rawValue: raw) ?? .home
        }
        return .home
    }
}

struct MoreMenuView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileHubView()
                    } label: {
                        ProfileHubRowLabel(me: mes.first)
                    }
                }
                Section("학습") {
                    NavigationLink { DDayListView() } label: {
                        Label("D-Day", systemImage: "flag.fill")
                    }
                    NavigationLink { StatsView() } label: {
                        Label("통계", systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink { SubjectListView() } label: {
                        Label("과목", systemImage: "books.vertical.fill")
                    }
                    NavigationLink { PlantDetailView() } label: {
                        Label("내 바다", systemImage: "water.waves")
                    }
                }
                Section("소셜") {
                    NavigationLink { FriendsView() } label: {
                        Label("친구", systemImage: "person.2.fill")
                    }
                }
            }
            .navigationTitle("더보기")
        }
    }
}

private struct ProfileHubRowLabel: View {
    let me: FriendProfileModel?
    @State private var server = ServerMode.shared

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DT.Color.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(me?.nickname ?? "내 프로필")
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(me?.friendCode ?? "—")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DT.Color.textSecondary)
                    Circle()
                        .fill(server.isOnline ? DT.Color.success : DT.Color.warning)
                        .frame(width: 6, height: 6)
                    Text(server.isOnline ? "온라인" : "오프라인")
                        .font(.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview { RootView() }
