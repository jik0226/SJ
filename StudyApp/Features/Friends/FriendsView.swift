// FriendsView — list of friends, my friend code, add by code, send cellog.

import SwiftUI
import SwiftData
import StudyCore

struct FriendsView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<FriendProfileModel> { $0.isMe == false && $0.isBlocked == false },
        sort: \FriendProfileModel.addedAt
    )
    private var friends: [FriendProfileModel]

    @Query(
        filter: #Predicate<FriendProfileModel> { $0.isBlocked == true },
        sort: \FriendProfileModel.addedAt
    )
    private var blockedFriends: [FriendProfileModel]

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    if let me = mes.first {
                        myProfileCard(me: me)
                    }
                    friendListSection
                    if !blockedFriends.isEmpty {
                        blockedSection
                    }
                    Spacer(minLength: DT.Spacing.xxl)
                }
                .padding(.horizontal, DT.Spacing.lg)
                .padding(.top, DT.Spacing.lg)
            }
            .background(DT.Color.surface.ignoresSafeArea())
            .navigationTitle("친구")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddFriendSheet()
            }
            .task {
                _ = SocialService.me(in: context)
                SocialService.seedDemoFriendsIfNeeded(in: context)
            }
        }
    }

    private var blockedSection: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.sm) {
            Text("차단됨")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
                .padding(.horizontal, DT.Spacing.xs)
            ForEach(blockedFriends) { friend in
                BlockedRow(friend: friend)
            }
        }
        .padding(.top, DT.Spacing.lg)
    }

    private func myProfileCard(me: FriendProfileModel) -> some View {
        VStack(spacing: DT.Spacing.sm) {
            Text("내 친구코드")
                .font(DT.Typography.caption)
                .foregroundStyle(DT.Color.textSecondary)
            Text(me.friendCode)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(DT.Color.primary)
            Text(me.nickname)
                .font(DT.Typography.headline)
                .foregroundStyle(DT.Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.lg)
        .padding(.horizontal, DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    @ViewBuilder
    private var friendListSection: some View {
        if friends.isEmpty {
            Text("친구를 추가해보세요")
                .font(DT.Typography.body)
                .foregroundStyle(DT.Color.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: DT.Spacing.md) {
                ForEach(friends) { friend in
                    FriendRow(friend: friend)
                }
            }
        }
    }
}

private struct FriendRow: View {
    let friend: FriendProfileModel
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(DT.Color.primary)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.nickname)
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text("\(friend.friendCode) · 오늘 \(friend.todayStudyMinutes)분")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
        }
        .padding(DT.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
        .contextMenu {
            Button(role: .destructive) {
                SocialService.block(friend, in: context)
            } label: {
                Label("차단", systemImage: "hand.raised.fill")
            }
        }
    }
}

private struct BlockedRow: View {
    let friend: FriendProfileModel
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(DT.Color.error)
                .frame(width: 36, height: 36)
                .background(Circle().fill(DT.Color.error.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.nickname)
                    .font(DT.Typography.headline)
                    .foregroundStyle(DT.Color.textPrimary)
                Text(friend.friendCode)
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
            Button("차단 해제") {
                SocialService.unblock(friend, in: context)
            }
            .font(DT.Typography.caption)
            .buttonStyle(.bordered)
            .tint(DT.Color.primary)
        }
        .padding(DT.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }
}

private struct AddFriendSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ABC234", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: code) { _, newValue in
                            // Strip forbidden characters as the user types so
                            // visible input matches `FriendCode.isValid`.
                            let cleaned = FriendCode.sanitize(newValue)
                            if cleaned != newValue { code = cleaned }
                        }
                } header: {
                    Text("친구 코드")
                } footer: {
                    Text("A–Z (I, O 제외) · 2–9 의 6자리")
                        .font(.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(DT.Color.error)
                }
            }
            .navigationTitle("친구 추가")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("추가") { add() }
                        .disabled(!FriendCode.isValid(code))
                }
            }
        }
    }

    private func add() {
        do {
            _ = try SocialService.addFriend(byCode: code, in: context)
            dismiss()
        } catch SocialError.invalidCode {
            errorMessage = "코드 형식이 올바르지 않습니다."
        } catch {
            errorMessage = "추가에 실패했습니다."
        }
    }
}
