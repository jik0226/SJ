// FriendDetailView — opens when a friend row is tapped.
// Shows the friend's public summary (whatever they opted to share) and
// provides clear destructive actions (block / delete) instead of hiding
// them in a long-press context menu the user is unlikely to find.

import SwiftUI
import SwiftData
import StudyCore

struct FriendDetailView: View {
    let friend: FriendProfileModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingBlockConfirm = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: DT.Spacing.md) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(DT.Color.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.nickname).font(.title3.weight(.semibold))
                        Text(friend.friendCode)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DT.Color.textSecondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, DT.Spacing.xs)
            }

            Section("오늘 학습") {
                LabeledContent("순공시간", value: "\(friend.todayStudyMinutes)분")
            }

            Section {
                Button {
                    showingBlockConfirm = true
                } label: {
                    Label(friend.isBlocked ? "차단 해제" : "차단",
                          systemImage: friend.isBlocked ? "hand.raised.slash" : "hand.raised.fill")
                }
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("친구 삭제", systemImage: "trash")
                }
            } footer: {
                Text("차단된 친구의 메시지는 채팅방에서 숨겨집니다. 친구 삭제는 본인 측에서만 적용됩니다.")
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
        }
        .navigationTitle("친구")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            friend.isBlocked ? "차단을 해제할까요?" : "이 친구를 차단할까요?",
            isPresented: $showingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(friend.isBlocked ? "차단 해제" : "차단",
                   role: friend.isBlocked ? .none : .destructive) {
                if friend.isBlocked {
                    SocialService.unblock(friend, in: context)
                } else {
                    SocialService.block(friend, in: context)
                }
            }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog(
            "이 친구를 삭제할까요?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                SocialService.removeFriend(friend, in: context)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("내 친구 목록에서만 제거됩니다. 상대방은 그대로 유지됩니다.")
        }
    }
}
