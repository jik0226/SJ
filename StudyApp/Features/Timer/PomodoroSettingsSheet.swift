// PomodoroSettingsSheet — adjust work / rest minutes for the pomodoro cycle.
// Persisted globally via PomodoroSettings; takes effect on the next session.

import SwiftUI

struct PomodoroSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workText: String = String(PomodoroSettings.workMinutes)
    @State private var restText: String = String(PomodoroSettings.restMinutes)
    @State private var enabled: Bool = PomodoroSettings.isEnabled

    /// 1..240 — a 4-hour work block is a hard upper bound to prevent
    /// "0 minutes" or accidental triple-digit typos from breaking the dial.
    private let allowedRange: ClosedRange<Int> = 1...240

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("포모도로 사용", isOn: $enabled)
                } footer: {
                    Text("집중 시간이 끝나면 타이머가 자동으로 일시정지되고 알림이 옵니다. 휴식 후 직접 재개해주세요.")
                }
                Section {
                    HStack {
                        TextField("분", text: $workText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text("분").foregroundStyle(DT.Color.textSecondary)
                        Stepper("", value: workBinding(), in: allowedRange)
                            .labelsHidden()
                    }
                } header: {
                    Text("집중 시간")
                } footer: {
                    Text("1분 ~ 240분 사이로 자유롭게 설정할 수 있어요.")
                }
                Section {
                    HStack {
                        TextField("분", text: $restText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        Text("분").foregroundStyle(DT.Color.textSecondary)
                        Stepper("", value: restBinding(), in: allowedRange)
                            .labelsHidden()
                    }
                } header: {
                    Text("휴식 시간")
                }
            }
            .navigationTitle("포모도로")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }.fontWeight(.semibold)
                        .disabled(parsedWork == nil || parsedRest == nil)
                }
            }
        }
    }

    private var parsedWork: Int? {
        Int(workText).flatMap { allowedRange.contains($0) ? $0 : nil }
    }
    private var parsedRest: Int? {
        Int(restText).flatMap { allowedRange.contains($0) ? $0 : nil }
    }

    private func workBinding() -> Binding<Int> {
        Binding(
            get: { parsedWork ?? PomodoroSettings.workMinutes },
            set: { workText = String($0) }
        )
    }
    private func restBinding() -> Binding<Int> {
        Binding(
            get: { parsedRest ?? PomodoroSettings.restMinutes },
            set: { restText = String($0) }
        )
    }

    private func save() {
        guard let w = parsedWork, let r = parsedRest else { return }
        PomodoroSettings.isEnabled = enabled
        PomodoroSettings.workMinutes = w
        PomodoroSettings.restMinutes = r
        dismiss()
    }
}
