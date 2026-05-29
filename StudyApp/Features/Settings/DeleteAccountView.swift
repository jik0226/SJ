// DeleteAccountView — in-app account & data deletion (App Review 5.1.1(v)).
// Double-confirms, runs the erase, then drops the user back to a clean empty
// state with a fresh anonymous account.

import SwiftUI
import SwiftData

struct DeleteAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingConfirm = false
    @State private var isDeleting = false
    @State private var didComplete = false

    var body: some View {
        Form {
            Section {
                Text("계정과 모든 데이터를 삭제합니다.")
                    .font(.headline)
            } footer: {
                Text("이 작업은 되돌릴 수 없습니다.")
                    .foregroundStyle(DT.Color.error)
            }

            Section("삭제되는 항목") {
                bullet("프로필(닉네임·친구 코드)과 계정 식별자")
                bullet("학습·운동·플래너·디데이·바다 기록(서버 백업 포함)")
                bullet("친구 목록과 그룹 참여 정보")
                bullet("이 기기에 저장된 모든 데이터")
            }

            Section {
                bullet("공유 채팅방의 메시지는 다른 참여자에게 남을 수 있어요(보낸 사람 정보는 식별되지 않습니다).")
            } header: {
                Text("참고")
            }

            Section {
                Button(role: .destructive) {
                    showingConfirm = true
                } label: {
                    HStack {
                        if isDeleting { ProgressView().padding(.trailing, 4) }
                        Text(isDeleting ? "삭제 중…" : "계정 및 데이터 삭제")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isDeleting)
            }
        }
        .navigationTitle("계정 삭제")
        .confirmationDialog(
            "정말 삭제할까요?",
            isPresented: $showingConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { runDeletion() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("계정과 모든 데이터가 영구히 삭제됩니다. 되돌릴 수 없습니다.")
        }
        .alert("삭제 완료", isPresented: $didComplete) {
            Button("확인") { dismiss() }
        } message: {
            Text("계정과 데이터가 삭제되었습니다. 앱이 새 계정으로 다시 시작됩니다.")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DT.Spacing.sm) {
            Text("•")
            Text(text)
        }
        .font(.callout)
        .foregroundStyle(DT.Color.textSecondary)
    }

    private func runDeletion() {
        isDeleting = true
        Task {
            await AccountDeletionService.deleteEverything(context: context)
            isDeleting = false
            didComplete = true
        }
    }
}
