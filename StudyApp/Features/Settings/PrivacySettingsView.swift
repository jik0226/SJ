// PrivacySettingsView — per-field opt-in toggles for what friends can see.
// Reads/writes PrivacyPreferences; triggers an immediate publish so the
// server reflects the new state without waiting for the next session save.

import SwiftUI
import SwiftData

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var values: [PrivacyPreferences.Field: Bool] = [:]

    var body: some View {
        Form {
            Section {
                ForEach(PrivacyPreferences.Field.allCases, id: \.rawValue) { field in
                    Toggle(field.label, isOn: binding(for: field))
                        .tint(DT.Color.primary)
                }
            } header: {
                Text("친구에게 보일 항목")
            } footer: {
                Text("기본값은 모두 비공개입니다. 켠 항목만 다른 사용자에게 보입니다. 친구코드와 닉네임은 친구 추가에 필요해 항상 공개됩니다.")
                    .font(.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Section("각 항목 설명") {
                ForEach(PrivacyPreferences.Field.allCases, id: \.rawValue) { field in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.label).font(.subheadline.weight(.semibold))
                        Text(field.detail)
                            .font(.caption)
                            .foregroundStyle(DT.Color.textSecondary)
                    }
                }
            }
        }
        .navigationTitle("공유 설정")
        .onAppear { hydrate() }
    }

    private func hydrate() {
        for f in PrivacyPreferences.Field.allCases {
            values[f] = PrivacyPreferences.isEnabled(f)
        }
    }

    private func binding(for field: PrivacyPreferences.Field) -> Binding<Bool> {
        Binding(
            get: { values[field] ?? PrivacyPreferences.isEnabled(field) },
            set: { newValue in
                values[field] = newValue
                PrivacyPreferences.setEnabled(field, newValue)
                // Push to server right away so the toggle is honored without
                // having to wait for the next session save to fire publishMe.
                appState.publishPublicSnapshot(context: context)
            }
        )
    }
}
