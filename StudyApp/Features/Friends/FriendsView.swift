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
    @State private var openingChatWith: FriendProfileModel?
    @State private var activeChat: StudyGroupModel?
    @State private var dmError: String?
    @State private var server = ServerMode.shared
    @State private var draftNickname = ""

    private var nicknameSet: Bool {
        !(mes.first?.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DT.Spacing.lg) {
                    if !server.isOnline {
                        OfflineNoticeBanner()
                    }
                    if !nicknameSet {
                        // Friend features need a real display name first,
                        // otherwise the other side sees a blank entry.
                        nicknamePromptCard
                    } else if let me = mes.first {
                        myProfileCard(me: me)
                        friendListSection
                        if !blockedFriends.isEmpty {
                            blockedSection
                        }
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
                    .disabled(!server.isOnline || !nicknameSet)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddFriendSheet()
            }
            .navigationDestination(item: $activeChat) { group in
                GroupChatView(group: group)
            }
            .alert(
                "채팅을 열 수 없어요",
                isPresented: Binding(
                    get: { dmError != nil },
                    set: { if !$0 { dmError = nil } }
                ),
                actions: { Button("확인", role: .cancel) {} },
                message: { Text(dmError ?? "") }
            )
            .task {
                _ = SocialService.me(in: context)
                SocialService.seedDemoFriendsIfNeeded(in: context)
            }
        }
    }

    private func openDM(with friend: FriendProfileModel) {
        guard openingChatWith == nil else { return }
        openingChatWith = friend
        Task {
            defer { openingChatWith = nil }
            do {
                let group = try await SocialService.ensureDirectMessageGroup(
                    with: friend, in: context
                )
                activeChat = group
            } catch SocialError.serverPublishFailed {
                dmError = "서버 연결에 문제가 있어요. 잠시 후 다시 시도해주세요."
            } catch {
                dmError = "채팅방을 열 수 없어요. 잠시 후 다시 시도해주세요."
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

    private var nicknamePromptCard: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.md) {
            HStack(spacing: DT.Spacing.sm) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(DT.Color.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("친구에게 보일 이름을 정해주세요")
                        .font(DT.Typography.headline)
                        .foregroundStyle(DT.Color.textPrimary)
                    Text("이름을 정하면 친구코드 공유·친구 추가·채팅을 쓸 수 있어요.")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            TextField("예: 인겸", text: $draftNickname)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit { saveNickname() }
            Button(action: saveNickname) {
                Text("이름 저장")
                    .font(DT.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DT.Spacing.sm)
                    .background(Capsule().fill(
                        draftNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DT.Color.primary.opacity(0.4) : DT.Color.primary
                    ))
            }
            .buttonStyle(.plain)
            .disabled(draftNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(DT.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }

    private func saveNickname() {
        let clean = draftNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let me = SocialService.me(in: context)
        me.nickname = clean
        if Persistence.save({ try context.save() }, context: "friends.setNickname") != nil {
            FirestoreSyncService.shared.publishMe(me)
        }
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
                .textSelection(.enabled)
            Text(me.nickname)
                .font(DT.Typography.headline)
                .foregroundStyle(DT.Color.textPrimary)
            myCodeActions(me: me)
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

    private func myCodeActions(me: FriendProfileModel) -> some View {
        let shareText = "SJ 친구 코드: \(me.friendCode)\n앱에서 ‘친구 추가’로 입력해줘."
        return HStack(spacing: DT.Spacing.sm) {
            Button {
                UIPasteboard.general.string = me.friendCode
                copyHaptic()
            } label: {
                Label("복사", systemImage: "doc.on.doc")
                    .font(DT.Typography.caption)
                    .padding(.horizontal, DT.Spacing.md)
                    .padding(.vertical, DT.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(DT.Color.primary)
            ShareLink(item: shareText) {
                Label("공유", systemImage: "square.and.arrow.up")
                    .font(DT.Typography.caption)
                    .padding(.horizontal, DT.Spacing.md)
                    .padding(.vertical, DT.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(DT.Color.primary)
        }
        .padding(.top, DT.Spacing.xs)
    }

    private func copyHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
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
                    // Tapping the row opens the 1:1 chat (the action users
                    // expect from "tap a friend"). The trailing info icon is a
                    // separate tap target for the profile / block / delete.
                    Button {
                        openDM(with: friend)
                    } label: {
                        FriendRow(
                            friend: friend,
                            isOpening: openingChatWith?.friendCode == friend.friendCode
                        )
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .trailing) {
                        if openingChatWith?.friendCode != friend.friendCode {
                            NavigationLink {
                                FriendDetailView(friend: friend)
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(DT.Color.textSecondary)
                                    .padding(.trailing, DT.Spacing.lg)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct FriendRow: View {
    let friend: FriendProfileModel
    var isOpening: Bool = false
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
            if isOpening {
                ProgressView()
            } else {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(DT.Color.primary.opacity(0.4))
                // Trailing padding leaves room for the info-icon overlay.
                Spacer().frame(width: DT.Spacing.lg)
            }
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

// Internal so the chat inbox can offer "친구 추가" without re-implementing it.
struct AddFriendSheet: View {
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("A–Z (I, O 제외) · 2–9 의 6자리")
                        Text("친구가 앱을 한 번이라도 실행해 자기 코드를 서버에 등록해야 추가할 수 있어요. 추가하면 양쪽 친구 목록에 자동으로 등록됩니다.")
                    }
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
        Task {
            do {
                _ = try await SocialService.addFriend(byCode: code, in: context)
                dismiss()
            } catch SocialError.invalidCode {
                errorMessage = "코드 형식이 올바르지 않습니다."
            } catch SocialError.selfCode {
                errorMessage = "내 코드는 친구로 추가할 수 없어요."
            } catch SocialError.codeNotFound {
                errorMessage = "해당 코드의 사용자를 찾을 수 없어요. 친구가 앱을 한 번 실행해 코드를 등록해야 합니다."
            } catch SocialError.lookupError(let err) {
                errorMessage = err.errorDescription
            } catch SocialError.serverPublishFailed {
                errorMessage = "서버 연결에 문제가 있어요. 잠시 후 다시 시도해주세요."
            } catch SocialError.saveFailed {
                errorMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
            } catch {
                errorMessage = "추가에 실패했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }
}
