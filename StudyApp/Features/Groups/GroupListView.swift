// GroupListView — study groups the user belongs to. Tap to open chat,
// "+" to create new, "참여" to join by code.

import SwiftUI
import SwiftData
import StudyCore

struct GroupListView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]

    @Query(sort: \StudyGroupModel.createdAt, order: .reverse)
    private var allGroups: [StudyGroupModel]

    @State private var showingCreate = false
    @State private var showingJoin = false
    @State private var navigateToGroup: StudyGroupModel?
    @State private var server = ServerMode.shared

    private var myGroups: [StudyGroupModel] {
        let myCodes = Set(mes.filter { $0.isMe }.map(\.friendCode))
        guard !myCodes.isEmpty else { return [] }
        return allGroups.filter { group in
            // DM groups are surfaced from the friends list, not here, so the
            // group screen stays focused on multi-member study groups.
            guard !group.code.hasPrefix(SocialService.directMessageCodePrefix) else { return false }
            return !myCodes.isDisjoint(with: group.memberCodes)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("스터디 그룹")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("새 그룹 만들기") { showingCreate = true }
                            Button("코드로 참여") { showingJoin = true }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(!server.isOnline)
                    }
                }
                .sheet(isPresented: $showingCreate) {
                    // After create we navigate straight into the chat thread.
                    // The detour avoids SwiftData's brief @Query reactive lag
                    // where a freshly-inserted group can momentarily look
                    // missing from the list.
                    CreateGroupSheet(onCreated: { group in
                        navigateToGroup = group
                    })
                }
                .sheet(isPresented: $showingJoin) {
                    JoinGroupSheet(onJoined: { group in
                        navigateToGroup = group
                    })
                }
                .navigationDestination(item: $navigateToGroup) { group in
                    GroupChatView(group: group)
                }
                .task {
                    _ = SocialService.me(in: context)
                    SocialService.seedDemoFriendsIfNeeded(in: context)
                    SocialService.seedDemoGroupIfNeeded(in: context)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if myGroups.isEmpty {
            ScrollView {
                VStack(spacing: DT.Spacing.md) {
                    if !server.isOnline {
                        OfflineNoticeBanner()
                            .padding(.horizontal, DT.Spacing.lg)
                    }
                    Spacer(minLength: DT.Spacing.xxl)
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundStyle(DT.Color.textSecondary)
                    Text("아직 그룹이 없어요")
                        .font(DT.Typography.body)
                        .foregroundStyle(DT.Color.textSecondary)
                    Text("새 그룹을 만들거나 코드로 참여해보세요.")
                        .font(DT.Typography.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .background(DT.Color.surface.ignoresSafeArea())
        } else {
            ScrollView {
                LazyVStack(spacing: DT.Spacing.md) {
                    if !server.isOnline {
                        OfflineNoticeBanner()
                    }
                    ForEach(myGroups) { group in
                        NavigationLink {
                            GroupChatView(group: group)
                        } label: {
                            GroupRow(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DT.Spacing.lg)
                .padding(.vertical, DT.Spacing.lg)
            }
            .background(DT.Color.surface.ignoresSafeArea())
        }
    }
}

private struct GroupRow: View {
    let group: StudyGroupModel
    @Environment(\.modelContext) private var context

    @Query private var allMessages: [ChatMessageModel]

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]

    private var unreadCount: Int {
        let gid = group.id
        let myCode = mes.first?.friendCode ?? ""
        return allMessages.filter {
            $0.groupId == gid
                && !$0.anyoneRead
                && !$0.isReported
                && $0.senderFriendCode != myCode
        }.count
    }

    private var latestMessage: ChatMessageModel? {
        let gid = group.id
        return allMessages
            .filter { $0.groupId == gid && !$0.isReported }
            .sorted { $0.sentAt > $1.sentAt }
            .first
    }

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(DT.Color.primary))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(group.name)
                        .font(DT.Typography.headline)
                        .foregroundStyle(DT.Color.textPrimary)
                    Spacer()
                    if let latest = latestMessage {
                        Text(latest.sentAt.formatted(.relative(presentation: .numeric)))
                            .font(DT.Typography.caption)
                            .foregroundStyle(DT.Color.textSecondary)
                    }
                }
                Text(latestMessage?.text ?? "아직 대화가 없어요")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
                    .lineLimit(1)
                HStack {
                    Text("\(group.memberCodes.count)명 · 코드 \(group.code)")
                        .font(.system(size: 11))
                        .foregroundStyle(DT.Color.textSecondary)
                    Spacer()
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(DT.Color.error))
                    }
                }
            }
        }
        .padding(DT.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DT.Radius.card)
                .fill(DT.Color.background)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 1)
    }
}

// Internal so the chat inbox can offer "새 그룹" directly.
struct CreateGroupSheet: View {
    let onCreated: (StudyGroupModel) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var errorMessage: String?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("그룹 이름") {
                    TextField("예: 수능 D-100", text: $name)
                }
                Section {
                    Text("새 그룹을 만들면 자동으로 코드가 생성됩니다. 친구에게 코드를 공유해 초대하세요.")
                        .font(.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(DT.Color.error)
                    }
                }
            }
            .navigationTitle("새 그룹")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.disabled(isCreating)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("만들기") { createGroup() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }

    private func createGroup() {
        errorMessage = nil
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                let group = try await SocialService.createGroup(name: name, in: context)
                onCreated(group)
                dismiss()
            } catch SocialError.emptyGroupName {
                errorMessage = "그룹 이름을 입력해주세요."
            } catch SocialError.saveFailed {
                errorMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
            } catch SocialError.serverPublishFailed {
                errorMessage = "서버 연결에 문제가 있어요. 잠시 후 다시 시도해주세요."
            } catch {
                errorMessage = "그룹을 만들지 못했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }
}

// Internal so the chat inbox can offer "그룹 참여" directly.
struct JoinGroupSheet: View {
    let onJoined: (StudyGroupModel) -> Void
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
                            let cleaned = GroupCode.sanitize(newValue)
                            if cleaned != newValue { code = cleaned }
                        }
                } header: {
                    Text("그룹 코드")
                } footer: {
                    Text("그룹장이 알려준 6자리 코드를 입력하세요.")
                        .font(.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(DT.Color.error)
                }
            }
            .navigationTitle("그룹 참여")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("참여") { join() }
                        .disabled(!GroupCode.isValid(code))
                }
            }
        }
    }

    private func join() {
        Task {
            do {
                let group = try await SocialService.joinGroup(byCode: code, in: context)
                onJoined(group)
                dismiss()
            } catch SocialError.invalidGroupCode {
                errorMessage = "코드 형식이 올바르지 않습니다."
            } catch SocialError.groupNotFound {
                errorMessage = "해당 코드의 그룹을 찾을 수 없어요."
            } catch SocialError.lookupError(let err) {
                errorMessage = err.errorDescription
            } catch SocialError.serverPublishFailed {
                errorMessage = "서버 연결에 문제가 있어요. 잠시 후 다시 시도해주세요."
            } catch SocialError.saveFailed {
                errorMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
            } catch {
                errorMessage = "참여에 실패했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }
}
