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

    private var myGroups: [StudyGroupModel] {
        guard let me = mes.first else { return [] }
        return allGroups.filter { $0.memberCodes.contains(me.friendCode) }
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
                    }
                }
                .sheet(isPresented: $showingCreate) {
                    CreateGroupSheet()
                }
                .sheet(isPresented: $showingJoin) {
                    JoinGroupSheet()
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
            VStack(spacing: DT.Spacing.md) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DT.Color.surface.ignoresSafeArea())
        } else {
            ScrollView {
                LazyVStack(spacing: DT.Spacing.md) {
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

private struct CreateGroupSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

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
            }
            .navigationTitle("새 그룹")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("만들기") {
                        _ = try? SocialService.createGroup(name: name, in: context)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct JoinGroupSheet: View {
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
        do {
            _ = try SocialService.joinGroup(byCode: code, in: context)
            dismiss()
        } catch SocialError.invalidGroupCode {
            errorMessage = "코드 형식이 올바르지 않습니다."
        } catch SocialError.groupNotFound {
            errorMessage = "해당 코드의 그룹을 찾을 수 없어요."
        } catch {
            errorMessage = "참여에 실패했어요."
        }
    }
}
