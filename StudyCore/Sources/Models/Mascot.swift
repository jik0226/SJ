// Mascot — the growing character on the home screen.
// Species and stage drive which illustration asset to render.

import Foundation

public enum MascotSpecies: String, Codable, Sendable, CaseIterable {
    case rabbit
    case fox
    case bear
    case cat
    case dragon
}

public struct Mascot: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var species: MascotSpecies
    public var name: String
    public var exp: Int
    public var stage: Int

    public init(
        id: UUID = UUID(),
        species: MascotSpecies,
        name: String,
        exp: Int = 0,
        stage: Int = 0
    ) {
        self.id = id
        self.species = species
        self.name = name
        self.exp = max(0, exp)
        self.stage = max(0, min(stage, Mascot.maxStage))
    }

    /// Stages 0..5 inclusive (6 forms: egg → sprout → child → teen → adult → final).
    /// Thresholds in `EvolutionRules.stageThresholds` define stage cutoffs.
    public static let maxStage: Int = 5
}
