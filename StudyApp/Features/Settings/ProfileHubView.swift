// ProfileHubView — single screen for "내 정보" so the user can see in one
// place: who they are, their friend code, server connection state, what
// they're sharing with friends, and the account linking state. Replaces
// the previous scatter across MoreMenu items.

import SwiftUI
import SwiftData
import StudyCore

struct ProfileHubView: View {
    @Environment(\.modelContext) private var context
    @State private var server = ServerMode.shared
    @State private var auth = AuthBootstrap.shared

    @Query(filter: #Predicate<FriendProfileModel> { $0.isMe == true })
    private var mes: [FriendProfileModel]

    @State private var editingNickname = false
    @State private var draftNickname = ""
    @State private var copiedAt: Date?

    var body: some View {
        Form {
            identitySection
            connectionSection
            sharingSection
            accountSection
            techDetailSection
        }
        .navigationTitle("내 프로필")
        .navigationBarTitleDisplayMode(.inline)
        .alert("닉네임 변경", isPresented: $editingNickname) {
            TextField("닉네임", text: $draftNickname)
            Button("취소", role: .cancel) {}
            Button("저장") { saveNickname() }
        } message: {
            Text("친구가 보게 될 이름이에요.")
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section {
            HStack(spacing: DT.Spacing.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DT.Color.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mes.first?.nickname ?? "나")
                        .font(.title3.weight(.semibold))
                    if let code = mes.first?.friendCode {
                        HStack(spacing: 4) {
                            Text(code)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(DT.Color.textSecondary)
                                .textSelection(.enabled)
                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = code
                                #endif
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Spacer()
                Button {
                    draftNickname = mes.first?.nickname ?? ""
                    editingNickname = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, DT.Spacing.xs)
        }
    }

    private var connectionSection: some View {
        Section {
            HStack(spacing: DT.Spacing.sm) {
                Image(systemName: connectionIcon)
                    .foregroundStyle(connectionTint)
                Text(connectionLabel)
                    .font(.subheadline)
                    .foregroundStyle(DT.Color.textPrimary)
                Spacer()
            }
            if case .offline(let reason) = server.state {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
        } header: {
            Text("서버 연결")
        }
    }

    private var sharingSection: some View {
        Section {
            NavigationLink {
                PrivacySettingsView()
            } label: {
                HStack {
                    Label("공유 범위 설정", systemImage: "eye.trianglebadge.exclamationmark")
                    Spacer()
                    Text(sharingSummary)
                        .font(.caption)
                        .foregroundStyle(DT.Color.textSecondary)
                }
            }
        } header: {
            Text("친구에게 공개되는 항목")
        }
    }

    private var accountSection: some View {
        Section {
            NavigationLink {
                AccountLinkView()
            } label: {
                HStack {
                    Label(
                        auth.isLinked ? "Google 계정으로 보호됨" : "익명 계정 (이 폰에서만)",
                        systemImage: auth.isLinked ? "checkmark.seal.fill" : "person.crop.circle.dashed"
                    )
                    Spacer()
                    if let email = auth.linkedEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(DT.Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        } header: {
            Text("계정 연결")
        }
    }

    private var techDetailSection: some View {
        Section {
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = auth.currentUID ?? ""
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                copiedAt = Date()
            } label: {
                HStack {
                    Label("고객지원용 ID 복사", systemImage: "doc.on.doc")
                        .foregroundStyle(DT.Color.textPrimary)
                    Spacer()
                    if copiedJustNow {
                        // No chevron — the action is in-place. A short
                        // "복사 완료 ✓" confirmation replaces the disclosure
                        // hint so the user knows the tap did something.
                        Label("복사 완료", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption.bold())
                            .foregroundStyle(DT.Color.success)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: copiedJustNow)
        } header: {
            Text("문제가 있을 때")
        } footer: {
            Text("앱에 문제가 생겼을 때 운영자가 로그를 찾을 수 있게 도와주는 식별자예요. 평소엔 신경 쓰지 않아도 됩니다.")
                .font(.caption)
                .foregroundStyle(DT.Color.textSecondary)
        }
    }

    /// True for ~2 seconds after the copy tap so the "복사 완료" badge
    /// auto-fades. SwiftUI re-evaluates this every state mutation, but the
    /// state change happens only on tap so re-render cost is negligible.
    private var copiedJustNow: Bool {
        guard let at = copiedAt else { return false }
        return Date().timeIntervalSince(at) < 2.0
    }

    // MARK: - Helpers

    private var connectionIcon: String {
        switch server.state {
            case .bootstrapping: return "ellipsis.circle"
            case .online: return "checkmark.circle.fill"
            case .offline: return "wifi.exclamationmark"
        }
    }

    private var connectionTint: Color {
        switch server.state {
            case .bootstrapping: return DT.Color.textSecondary
            case .online: return DT.Color.success
            case .offline: return DT.Color.warning
        }
    }

    private var connectionLabel: String {
        switch server.state {
            case .bootstrapping: return "연결 확인 중…"
            case .online: return "온라인 — 친구·채팅 동작"
            case .offline: return "오프라인 — 로컬 모드"
        }
    }

    private var sharingSummary: String {
        let on = PrivacyPreferences.Field.allCases.filter { PrivacyPreferences.isEnabled($0) }
        if on.isEmpty { return "전부 비공개" }
        if on.count == PrivacyPreferences.Field.allCases.count { return "전부 공개" }
        return "\(on.count)개 항목"
    }

    private func saveNickname() {
        let trimmed = draftNickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let me = mes.first else { return }
        me.nickname = trimmed
        if Persistence.save({ try context.save() }, context: "profile.renameMe") != nil {
            FirestoreSyncService.shared.publishMe(me)
        }
    }
}
