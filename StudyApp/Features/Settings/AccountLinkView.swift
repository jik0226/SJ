// AccountLinkView — turns the anonymous UID into a permanent Google account.
// Linking preserves the UID so all existing friends / groups / chat history
// stay attached. Unlinked anon users keep working but lose data if they
// reinstall the app or change phones.

import SwiftUI

struct AccountLinkView: View {
    @State private var auth = AuthBootstrap.shared
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: auth.isLinked ? "checkmark.seal.fill" : "person.crop.circle.dashed")
                        .font(.system(size: 28))
                        .foregroundStyle(auth.isLinked ? DT.Color.success : DT.Color.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headlineText)
                            .font(.headline)
                        if let email = auth.linkedEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(DT.Color.textSecondary)
                        }
                    }
                }
                .padding(.vertical, DT.Spacing.xs)
            } footer: {
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }

            if !auth.isLinked {
                Section {
                    Button {
                        connectGoogle()
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .foregroundStyle(.red)
                            Text(isWorking ? "Google 로그인 중…" : "Google 계정으로 연결")
                                .fontWeight(.semibold)
                            Spacer()
                            if isWorking { ProgressView() }
                        }
                    }
                    .disabled(isWorking)
                } footer: {
                    Text("연결 후에도 친구코드와 모든 데이터는 그대로 유지됩니다. 다른 기기에서 같은 Google 계정으로 로그인하면 자동으로 복원돼요.")
                        .font(.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(DT.Color.error)
                }
            }

            Section("UID") {
                Text(auth.currentUID ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(DT.Color.textSecondary)
            }
        }
        .navigationTitle("계정 연결")
    }

    private var headlineText: String {
        auth.isLinked ? "Google 계정으로 보호되고 있어요" : "현재 익명 계정입니다"
    }

    private var footerText: String {
        if auth.isLinked {
            return "이 폰을 잃거나 새 폰으로 바꿔도 같은 Google 계정으로 로그인하면 모든 데이터가 자동으로 복원됩니다."
        }
        return "익명 계정은 키체인에 저장돼 같은 폰에서만 유지됩니다. 폰을 바꾸거나 앱을 삭제하면 친구/그룹/학습 기록 접근이 끊길 수 있어요. Google 계정으로 연결하면 안전해집니다."
    }

    private func connectGoogle() {
        errorMessage = nil
        isWorking = true
        Task {
            do {
                try await auth.linkWithGoogle()
            } catch let error as AuthBootstrap.LinkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
