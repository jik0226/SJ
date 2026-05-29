// GroupSheets — create / join group modal sheets used by the chat inbox.
// Extracted from the former GroupListView (whose list UI was superseded by
// ChatInboxView); only these two sheets remain in use.

import SwiftUI
import SwiftData
import StudyCore

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
