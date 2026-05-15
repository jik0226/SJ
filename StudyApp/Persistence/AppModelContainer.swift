// AppModelContainer — single ModelContainer for the app.
// Seeds default subjects, a dday, and a mascot on first launch.
//
// Recovery policy: SwiftData init failures NEVER delete user data. The legacy
// store is moved to `Documents/Backups/Study-<ISO timestamp>.sqlite` so the
// user can export it, and the failure is surfaced via `RecoveryState` so the
// UI can show a persistent banner instead of pretending nothing happened.

import Foundation
import SwiftData
import StudyCore

@MainActor
enum AppModelContainer {
    static let shared = Holder()

    /// Snapshot of how the container booted. Surfaced via `RecoveryState`
    /// so the home screen can warn the user when their data was sidelined.
    enum BootStatus: Sendable {
        case normal
        case startedFreshAfterBackup(backupURL: URL)
        case inMemoryFallback
    }

    @MainActor
    final class Holder {
        let container: ModelContainer
        let bootStatus: BootStatus

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
                self.bootStatus = .normal
                AppModelContainer.seedIfNeeded(container: container)
                RecoveryState.shared.report(.normal)
                return
            } catch {
                Persistence.log(error, context: "ModelContainer.initial")
            }

            // Likely cause on upgrade installs: legacy schema can't be opened
            // by the current model set. Until we ship a real
            // `SchemaMigrationPlan`, *move* the unreadable store to a backup
            // folder rather than deleting it — the user's data is preserved
            // and exportable, even though the app boots from a fresh store.
            let backupURL = Self.archiveLegacyStore(at: url)

            do {
                self.container = try ModelContainer(for: schema, configurations: [config])
                if let backupURL {
                    self.bootStatus = .startedFreshAfterBackup(backupURL: backupURL)
                } else {
                    // No legacy data existed — this is effectively a clean
                    // first boot, so don't alarm the user.
                    self.bootStatus = .normal
                }
                AppModelContainer.seedIfNeeded(container: container)
                RecoveryState.shared.report(bootStatus)
            } catch {
                Persistence.log(error, context: "ModelContainer.fallback")
                // Last resort: in-memory store so the app still boots even if
                // disk is unavailable. Surface this explicitly so the user
                // knows *this session's* writes won't persist.
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = (try? ModelContainer(for: schema, configurations: [memoryConfig]))
                    ?? Self.emergencyContainer(schema: schema)
                self.bootStatus = .inMemoryFallback
                RecoveryState.shared.report(.inMemoryFallback)
            }
        }

        /// Moves the unreadable store + sidecar files to
        /// `Documents/Backups/Study-<timestamp>.sqlite`. Returns the moved
        /// path, or nil if there was nothing to back up.
        ///
        /// We move (not copy) because SwiftData refuses to open a stale
        /// `.sqlite` even when it sits next to a healthy new one — and we
        /// don't want to silently delete the original. The backup folder
        /// stays out of the SwiftData store path so it never re-enters
        /// the recovery loop.
        private static func archiveLegacyStore(at url: URL) -> URL? {
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else { return nil }

            let backupsDir = url.deletingLastPathComponent()
                .appendingPathComponent("Backups", isDirectory: true)
            try? fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)

            let stamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let target = backupsDir.appendingPathComponent("Study-\(stamp).sqlite")

            do {
                try fm.moveItem(at: url, to: target)
            } catch {
                Persistence.log(error, context: "ModelContainer.archiveMain")
                // If we can't move the main file we cannot recover safely.
                // Fall back to nil so caller knows there's nothing archived.
                return nil
            }
            // Sidecar files: best-effort. A missing -wal/-shm is normal and
            // a failed move only loses incremental WAL state that the main
            // archive already supersedes.
            for suffix in ["-wal", "-shm"] {
                let from = URL(fileURLWithPath: url.path + suffix)
                guard fm.fileExists(atPath: from.path) else { continue }
                let to = backupsDir.appendingPathComponent("Study-\(stamp).sqlite\(suffix)")
                try? fm.moveItem(at: from, to: to)
            }
            return target
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
        migratePlantName(context: context)

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
        context.insert(PlantModel(name: "내 바다"))
    }

    /// One-shot migration: existing installs that were seeded with the old
    /// "내 새싹" name should silently roll over to the ocean wording so the
    /// home screen no longer surfaces the legacy mascot label.
    /// Idempotent — running it on a clean install is a no-op.
    private static func migratePlantName(context: ModelContext) {
        let plants = (try? context.fetch(FetchDescriptor<PlantModel>())) ?? []
        for plant in plants where plant.name == "내 새싹" {
            plant.name = "내 바다"
        }
    }
}
