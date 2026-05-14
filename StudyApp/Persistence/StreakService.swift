// StreakService — detects consecutive-day daily-goal achievements and fires
// `PlantProgressService.handleWeeklyStreakBonus` once each 7-day completion.
// Stored state lives in UserDefaults so the streak survives DB resets.

import Foundation
import SwiftData
import StudyCore

@MainActor
enum StreakService {
    private static let defaults = UserDefaults(suiteName: AppGroup.identifier)
        ?? .standard
    private static let calendar = PlannerCalendar(cutoffHour: 3)

    private static let lastAwardedDayKey = "streak.lastAwardedDay"
    private static let streakLengthKey = "streak.length"
    private static let lastGoalMetDayKey = "streak.lastGoalMetDay"

    static var currentLength: Int {
        defaults.integer(forKey: streakLengthKey)
    }

    static var isStreakAliveToday: Bool {
        let today = calendar.plannerDay(for: Date())
        let lastGoalMet = defaults.integer(forKey: lastGoalMetDayKey)
        return lastGoalMet == today
    }

    static func evaluate(context: ModelContext) {
        let today = calendar.plannerDay(for: Date())

        let lastGoalMet = defaults.integer(forKey: lastGoalMetDayKey)
        if lastGoalMet == today { return }

        guard let goalMet = anyDailyGoalMet(on: today, context: context),
              goalMet else { return }

        let yesterday = previousPlannerDay(today)
        var length = defaults.integer(forKey: streakLengthKey)
        if lastGoalMet == yesterday {
            length += 1
        } else {
            length = 1
        }
        defaults.set(today, forKey: lastGoalMetDayKey)
        defaults.set(length, forKey: streakLengthKey)

        if length >= 7 {
            let lastAwarded = defaults.integer(forKey: lastAwardedDayKey)
            if lastAwarded == 0 || daysBetween(lastAwarded, today) >= 7 {
                PlantProgressService.handleWeeklyStreakBonus(context: context)
                NotificationsService.postWeeklyStreak()
                defaults.set(today, forKey: lastAwardedDayKey)
            }
        }
    }

    private static func anyDailyGoalMet(on plannerDay: Int, context: ModelContext) -> Bool? {
        let subjects = (try? context.fetch(FetchDescriptor<SubjectModel>())) ?? []
        for subject in subjects {
            let subjectID = subject.id
            let predicate = #Predicate<StudySessionModel> {
                $0.plannerDay == plannerDay && $0.subjectID == subjectID
            }
            let sessions = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
            let total = sessions.reduce(0) { $0 + $1.totalSeconds }
            if subject.dailyTargetMinutes > 0,
               total >= subject.dailyTargetMinutes * 60 {
                return true
            }
        }
        return false
    }

    private static func previousPlannerDay(_ day: Int) -> Int {
        let y = day / 10000
        let m = (day % 10000) / 100
        let d = day % 100
        var comps = DateComponents(year: y, month: m, day: d)
        comps.hour = 12
        guard let date = Calendar.current.date(from: comps),
              let prev = Calendar.current.date(byAdding: .day, value: -1, to: date) else {
            return day
        }
        let pc = Calendar.current.dateComponents([.year, .month, .day], from: prev)
        return (pc.year ?? 0) * 10000 + (pc.month ?? 0) * 100 + (pc.day ?? 0)
    }

    private static func daysBetween(_ a: Int, _ b: Int) -> Int {
        guard let dateA = dateFromPlannerDay(a),
              let dateB = dateFromPlannerDay(b) else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: dateA),
            to: cal.startOfDay(for: dateB)
        )
        return abs(comps.day ?? 0)
    }

    private static func dateFromPlannerDay(_ day: Int) -> Date? {
        let y = day / 10000
        let m = (day % 10000) / 100
        let d = day % 100
        var comps = DateComponents(year: y, month: m, day: d)
        comps.hour = 12
        return Calendar.current.date(from: comps)
    }
}
