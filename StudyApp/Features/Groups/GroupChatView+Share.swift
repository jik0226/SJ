// GroupChatView+Share — the "오늘 기록 공유" sheet. Surfaces today's study,
// run, planner, ocean, and streak achievements as one-tap chat attachments.
// Split out of GroupChatView; it owns its own queries and dismiss handling.

import SwiftUI
import SwiftData
import StudyCore

struct ShareTodayRecordSheet: View {
    let group: StudyGroupModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let calendar = PlannerCalendar(cutoffHour: 3)

    @Query private var studySessions: [StudySessionModel]
    @Query private var runSessions: [RunSessionModel]
    @Query private var subjects: [SubjectModel]
    @Query private var plannerBlocks: [PlannerBlockModel]
    @Query private var plants: [PlantModel]

    @State private var errorMessage: String?

    private var today: Int { calendar.plannerDay(for: Date()) }

    private var todayStudy: Int {
        studySessions.filter { $0.plannerDay == today }.reduce(0) { $0 + $1.totalSeconds }
    }
    private var todayRunMeters: Double {
        runSessions.filter { $0.plannerDay == today }.reduce(0.0) { $0 + $1.distanceMeters }
    }
    private var todayPlannerSlots: [Int: String] {
        let byId = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0.colorHex) })
        var map: [Int: String] = [:]
        for block in plannerBlocks where block.plannerDay == today {
            if let sid = block.subjectID, let hex = byId[sid] { map[block.slotIndex] = hex }
        }
        return map
    }
    private var streakDays: Int { StreakService.currentLength }

    var body: some View {
        NavigationStack {
            List {
                Section("오늘 기록") {
                    if todayStudy > 0 {
                        shareButton("📚", "오늘 순공 \(todayStudy / 60)분") {
                            share(kind: .studySession, summary: "오늘 순공 \(todayStudy / 60)분")
                        }
                    }
                    if todayRunMeters > 0 {
                        let km = String(format: "%.2f", todayRunMeters / 1000)
                        shareButton("🏃", "오늘 러닝 \(km)km") {
                            share(kind: .runSession, summary: "오늘 러닝 \(km)km")
                        }
                    }
                    if todayStudy == 0 && todayRunMeters == 0 {
                        Text("아직 오늘 기록이 없어요").foregroundStyle(DT.Color.textSecondary)
                    }
                }
                Section("성취 공유") {
                    if !todayPlannerSlots.isEmpty {
                        shareButton("🗓️", "오늘 플래너 \(todayPlannerSlots.count)칸") {
                            sharePlanner()
                        }
                    }
                    if let plant = plants.first {
                        shareButton("🌊", "내 바다 (\(plant.name))") {
                            shareOcean(plant)
                        }
                    }
                    if streakDays > 0 {
                        shareButton("🔥", "연속 학습 \(streakDays)일") {
                            shareStreak()
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(DT.Typography.caption)
                            .foregroundStyle(DT.Color.error)
                    }
                }
            }
            .navigationTitle("공유하기")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() } }
            }
        }
    }

    private func shareButton(_ emoji: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(emoji)
                Text(title).foregroundStyle(DT.Color.textPrimary)
                Spacer()
                Image(systemName: "paperplane")
                    .foregroundStyle(DT.Color.primary)
            }
        }
    }

    // MARK: - Share actions

    private func sharePlanner() {
        let payload = AttachmentPayload.Planner(
            slots: todayPlannerSlots.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value }
        )
        share(kind: .plannerDay,
              summary: "오늘 플래너 \(todayPlannerSlots.count)칸 완료",
              payload: encode(payload))
    }

    private func shareOcean(_ plant: PlantModel) {
        let payload = AttachmentPayload.Ocean(
            seed: plant.seed, study: plant.studyMinutes,
            workout: plant.workoutMinutes, name: plant.name
        )
        share(kind: .oceanSnapshot,
              summary: "내 바다 · 공부 \(plant.studyMinutes)분 / 운동 \(plant.workoutMinutes)분",
              payload: encode(payload))
    }

    private func shareStreak() {
        let payload = AttachmentPayload.Streak(days: streakDays)
        share(kind: .streak, summary: "연속 학습 \(streakDays)일째 🔥", payload: encode(payload))
    }

    private func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func share(kind: AttachedKind, summary: String, payload: String? = nil) {
        Task {
            let result = await SocialService.sendChat(
                text: "",
                to: group,
                attachedKind: kind,
                attachedRecordSummary: summary,
                attachedPayloadJSON: payload,
                in: context
            )
            switch result {
                case .sent, .serverPublishFailed:
                    dismiss()
                case .empty:
                    errorMessage = "공유할 내용이 비어 있어요."
                case .blockedByFilter(let reason):
                    errorMessage = reason
                case .saveFailed:
                    errorMessage = "공유에 실패했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }
}
