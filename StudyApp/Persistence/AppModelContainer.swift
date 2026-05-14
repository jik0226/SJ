// AppModelContainer — single ModelContainer for the app.
// Seeds default subjects, a dday, and a mascot on first launch.

import Foundation
import SwiftData
import StudyCore

@MainActor
enum AppModelContainer {
    static let shared = Holder()

    @MainActor
    final class Holder {
        let container: ModelContainer

        init() {
            let schema = Schema([
                SubjectModel.self,
                DDayModel.self,
                PlannerBlockModel.self,
                DailyPageModel.self,
                PlantModel.self,
                StudySessionModel.self,
                RunSessionModel.self,
                FriendProfileModel.self,
                StudyGroupModel.self,
                ChatMessageModel.self,
            ])
            // Pin to Documents/ so sandbox always grants write access.
            let url = URL.documentsDirectory.appendingPathComponent("Study.sqlite")
            let config = ModelConfiguration(schema: schema, url: url)

            do {
                self.container = try ModelContainer(for: schema, configurations: [config])
                AppModelContainer.seedIfNeeded(container: container)
                return
            } catch {
                Persistence.log(error, context: "ModelContainer.initial")
            }

            // Likely cause on upgrade installs: legacy schema can't be opened
            // by the current model set. Until we ship a real
            // `SchemaMigrationPlan`, the safe recovery is to delete the old
            // store and start with a fresh one rather than fatalError out of
            // the user's app on every launch.
            Self.removeLegacyStore(at: url)

            do {
                self.container = try ModelContainer(for: schema, configurations: [config])
                AppModelContainer.seedIfNeeded(container: container)
            } catch {
                Persistence.log(error, context: "ModelContainer.fallback")
                // Last resort: in-memory store so the app still boots even if
                // disk is unavailable. The user loses data this session but
                // doesn't get stuck in a crash loop.
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = (try? ModelContainer(for: schema, configurations: [memoryConfig]))
                    ?? Self.emergencyContainer(schema: schema)
            }
        }

        private static func removeLegacyStore(at url: URL) {
            let fm = FileManager.default
            // SwiftData stores `.sqlite` + `-wal` + `-shm` siblings.
            for suffix in ["", "-wal", "-shm"] {
                let candidate = URL(fileURLWithPath: url.path + suffix)
                if fm.fileExists(atPath: candidate.path) {
                    try? fm.removeItem(at: candidate)
                }
            }
        }

        /// Always-succeeds in-memory container — only reached when both disk
        /// init paths fail. Better than a fatalError loop.
        private static func emergencyContainer(schema: Schema) -> ModelContainer {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [config])
        }
    }

    private static func seedIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)

        seedSubjects(context: context)
        seedDDay(context: context)
        seedPlant(context: context)

        Persistence.save({ try context.save() }, context: "seed")

        // Push the seed D-Day + today's (zero) study time into the App Group
        // so widgets render real data on first install, not the placeholder.
        WidgetSyncService.syncAll(context: context)
    }

    private static func seedSubjects(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SubjectModel>())) ?? []
        guard existing.isEmpty else { return }

        let seeds: [SubjectModel] = [
            SubjectModel(name: "수학", colorHex: "#4DABF7", sfSymbol: "function",
                         allowPhoneUse: false, category: .study, dailyTargetMinutes: 120),
            SubjectModel(name: "영어", colorHex: "#FF6B6B", sfSymbol: "character.book.closed",
                         allowPhoneUse: false, category: .study, dailyTargetMinutes: 60),
            SubjectModel(name: "프로그래밍 강의", colorHex: "#B197FC", sfSymbol: "laptopcomputer",
                         allowPhoneUse: true, category: .study, dailyTargetMinutes: 90),
            SubjectModel(name: "러닝", colorHex: "#20C997", sfSymbol: "figure.run",
                         allowPhoneUse: true, category: .workout, dailyTargetMinutes: 30,
                         workoutType: .running),
        ]
        seeds.forEach(context.insert)
    }

    private static func seedDDay(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<DDayModel>())) ?? []
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        let suneungDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19))
                          ?? Date().addingTimeInterval(60 * 60 * 24 * 180)
        context.insert(DDayModel(title: "수능", targetDate: suneungDate,
                                 emoji: "📚", isPinned: true))
    }

    private static func seedPlant(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<PlantModel>())) ?? []
        guard existing.isEmpty else { return }
        context.insert(PlantModel(name: "내 새싹"))
    }
}
