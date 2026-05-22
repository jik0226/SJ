// StudySchema — versioned SwiftData schema + migration plan.
//
// Why this exists: every time a @Model gained a field we relied on the
// AppModelContainer backup-fallback, which effectively wiped data. With a
// VersionedSchema baseline + a SchemaMigrationPlan, additive/optional changes
// migrate *lightweight* (data preserved). New schema revisions append a
// `SchemaV2` etc. and a `.lightweight` (or `.custom`) stage between them.
//
// Note on stored defaults: SwiftData lightweight migration can only add a
// non-optional column if the property has a stored default (see
// ChatMessageModel.deliveryStateRaw). Keep that invariant when adding fields.

import Foundation
import SwiftData

/// Current baseline. All ten models as they exist today.
enum StudySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
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
        ]
    }
}

enum StudyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StudySchemaV1.self]
    }

    /// Empty today — V1 is the baseline. Future revisions add a stage, e.g.:
    ///   .lightweight(fromVersion: StudySchemaV1.self, toVersion: StudySchemaV2.self)
    static var stages: [MigrationStage] {
        []
    }
}
