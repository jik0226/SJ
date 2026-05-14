// StudyCore — umbrella module re-exporting every core subsystem.
// The iOS app imports StudyCore and gets the full surface.

@_exported import Models
@_exported import PlannerCalendar
@_exported import TimerEngine
@_exported import BackgroundGuard
@_exported import MascotEngine
@_exported import PlantFormula

public enum StudyCoreInfo {
    public static let version = "0.1.0-poc"
}
