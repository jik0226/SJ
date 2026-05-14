// StatsService — aggregates StudySession + RunSession into the buckets the
// stats UI consumes. Pure read paths; no mutations.

import Foundation
import SwiftData
import StudyCore

struct DailyTotal: Identifiable, Hashable {
    let plannerDay: Int
    let date: Date
    let totalSeconds: Int
    var id: Int { plannerDay }
}

struct SubjectTotal: Identifiable, Hashable {
    let subjectID: UUID
    let name: String
    let colorHex: String
    let totalSeconds: Int
    var id: UUID { subjectID }
}

struct HourlyBucket: Identifiable, Hashable {
    let hour: Int      // 0..23
    let totalSeconds: Int
    var id: Int { hour }
}

@MainActor
enum StatsService {
    private static let calendar = PlannerCalendar(cutoffHour: 3)

    static func daily(for plannerDay: Int, context: ModelContext) -> Int {
        let predicate = #Predicate<StudySessionModel> { $0.plannerDay == plannerDay }
        let sessions = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        return sessions.reduce(0) { $0 + $1.totalSeconds }
    }

    /// Last `days` planner days, oldest first.
    static func weekly(now: Date = Date(), days: Int = 7, context: ModelContext) -> [DailyTotal] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var results: [DailyTotal] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let plannerDay = plannerDayInt(for: date)
            let total = daily(for: plannerDay, context: context)
            results.append(DailyTotal(plannerDay: plannerDay, date: date, totalSeconds: total))
        }
        return results
    }

    /// Per-subject totals for a planner-day range.
    static func subjectBreakdown(
        from start: Int, to end: Int, context: ModelContext
    ) -> [SubjectTotal] {
        let sessionPredicate = #Predicate<StudySessionModel> {
            $0.plannerDay >= start && $0.plannerDay <= end
        }
        let sessions = (try? context.fetch(FetchDescriptor(predicate: sessionPredicate))) ?? []
        let subjects = (try? context.fetch(FetchDescriptor<SubjectModel>())) ?? []
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })

        var totals: [UUID: Int] = [:]
        for s in sessions {
            totals[s.subjectID, default: 0] += s.totalSeconds
        }
        return totals
            .compactMap { id, secs -> SubjectTotal? in
                guard let subject = subjectMap[id] else { return nil }
                return SubjectTotal(
                    subjectID: id, name: subject.name,
                    colorHex: subject.colorHex, totalSeconds: secs
                )
            }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    /// 24-hour heatmap derived from planner blocks for a given planner day.
    static func hourlyHeatmap(for plannerDay: Int, context: ModelContext) -> [HourlyBucket] {
        let predicate = #Predicate<PlannerBlockModel> { $0.plannerDay == plannerDay }
        let blocks = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        var perHour: [Int: Int] = [:]
        for b in blocks where b.subjectID != nil {
            let hour = b.slotIndex / 6
            perHour[hour, default: 0] += PlannerBlock.minutesPerSlot * 60
        }
        return (0..<24).map { hour in
            HourlyBucket(hour: hour, totalSeconds: perHour[hour] ?? 0)
        }
    }

    private static func plannerDayInt(for date: Date) -> Int {
        // Use the same cutoff calendar as the rest of the app so 00:00–02:59
        // still counts as the previous planner day in Stats too.
        calendar.plannerDay(for: date)
    }
}
