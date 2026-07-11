// DemoContentSeeder — fills realistic study time, planner blocks, a grown
// ocean, and chat so App Store screenshots look alive. STRICTLY gated behind
// `--seed-demo` (SocialService.demoSeedingEnabled); never runs on TestFlight
// or App Store builds. Reuses the default subjects / D-Day / plant that
// AppModelContainer already seeds, rather than creating duplicates.

import Foundation
import SwiftData
import StudyCore

@MainActor
enum DemoContentSeeder {
    private static let seededKey = "demo.contentSeeded"

    static func seedIfNeeded(context: ModelContext) {
        guard SocialService.demoSeedingEnabled else { return }

        // Always (re)ensure the social side — it has its own idempotency.
        defer {
            SocialService.seedDemoFriendsIfNeeded(in: context)
            SocialService.seedDemoGroupIfNeeded(in: context)
        }
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        let calendar = PlannerCalendar(cutoffHour: 3)
        let today = calendar.plannerDay(for: Date())

        let me = SocialService.me(in: context)
        if me.nickname.isEmpty { me.nickname = "수험생 J" }

        // Production installs start with zero subjects/D-Days by design, so
        // the demo creates its own showcase set here.
        let study = seedDemoSubjects(context: context)
        seedDemoDDay(context: context)
        guard !study.isEmpty else { return }

        seedSessions(study: study, today: today, context: context)
        seedPlanner(study: study, today: today, context: context)
        growOcean(context: context)

        Persistence.save({ try context.save() }, context: "demo.seedContent")
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    /// Demo showcase subjects — production no longer pre-seeds any.
    private static func seedDemoSubjects(context: ModelContext) -> [SubjectModel] {
        let existing = (try? context.fetch(FetchDescriptor<SubjectModel>())) ?? []
        let existingStudy = existing.filter { $0.categoryRaw == SubjectCategory.study.rawValue }
        guard existingStudy.isEmpty else { return existingStudy }
        let seeds: [SubjectModel] = [
            SubjectModel(name: "수학", colorHex: "#4DABF7", sfSymbol: "function",
                         allowPhoneUse: false, category: .study, dailyTargetMinutes: 120),
            SubjectModel(name: "영어", colorHex: "#FF6B6B", sfSymbol: "character.book.closed",
                         allowPhoneUse: false, category: .study, dailyTargetMinutes: 60),
            SubjectModel(name: "국어", colorHex: "#51CF66", sfSymbol: "book",
                         allowPhoneUse: false, category: .study, dailyTargetMinutes: 90),
            SubjectModel(name: "러닝", colorHex: "#20C997", sfSymbol: "figure.run",
                         allowPhoneUse: true, category: .workout, dailyTargetMinutes: 30,
                         workoutType: .running),
        ]
        seeds.forEach(context.insert)
        return seeds.filter { $0.categoryRaw == SubjectCategory.study.rawValue }
    }

    private static func seedDemoDDay(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<DDayModel>())) ?? []
        guard existing.isEmpty else { return }
        let target = Calendar.current.date(byAdding: .day, value: 131, to: Date()) ?? Date()
        context.insert(DDayModel(title: "수능", targetDate: target, emoji: "📚", isPinned: true))
    }

    private static func seedSessions(study: [SubjectModel], today: Int, context: ModelContext) {
        let now = Date()
        // Today: a believable couple of focused blocks on the first two subjects.
        let todayPlan: [(Int, Int)] = [(0, 80 * 60), (1, 45 * 60)]
        for (idx, seconds) in todayPlan where idx < study.count {
            insertSession(study[idx], seconds: seconds, day: today, at: now, context: context)
        }
        // Past 6 days so the weekly stats chart isn't flat.
        let perDayMinutes = [150, 95, 210, 60, 175, 120]
        for (offset, minutes) in perDayMinutes.enumerated() {
            let subject = study[offset % study.count]
            insertSession(
                subject, seconds: minutes * 60, day: today - (offset + 1),
                at: now.addingTimeInterval(Double(-(offset + 1)) * 86_400), context: context
            )
        }
    }

    private static func insertSession(
        _ subject: SubjectModel, seconds: Int, day: Int, at: Date, context: ModelContext
    ) {
        context.insert(StudySessionModel(
            subjectID: subject.id,
            startedAt: at.addingTimeInterval(Double(-seconds)),
            endedAt: at,
            totalSeconds: seconds,
            plannerDay: day
        ))
    }

    private static func seedPlanner(study: [SubjectModel], today: Int, context: ModelContext) {
        // 144 slots/day → 6 per hour. 09:00 = slot 54.
        let blocks: [(start: Int, count: Int, subject: Int)] = [
            (54, 9, 0),    // 09:00–10:30
            (63, 6, 2 % max(1, study.count)),  // 10:30–11:30
            (114, 9, 1 % max(1, study.count)), // 19:00–20:30
        ]
        for block in blocks where block.subject < study.count {
            for slot in block.start..<(block.start + block.count) {
                context.insert(PlannerBlockModel(
                    plannerDay: today, slotIndex: slot,
                    subjectID: study[block.subject].id, source: .manual
                ))
            }
        }
    }

    private static func growOcean(context: ModelContext) {
        // Grow the existing default plant so the home ocean has a rich shape.
        guard let plant = try? context.fetch(FetchDescriptor<PlantModel>()).first else { return }
        plant.recordActivity(kind: .study, minutes: 320)
        plant.recordActivity(kind: .workout, minutes: 30)
        plant.recordActivity(kind: .study, minutes: 180)
        plant.recordActivity(kind: .workout, minutes: 45)
        plant.recordActivity(kind: .study, minutes: 240)
    }
}
