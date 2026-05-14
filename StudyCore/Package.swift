// swift-tools-version: 6.3
// StudyCore — pure-Swift business logic for the iOS study app.
// Foundation-only, no UIKit/SwiftUI/SwiftData deps so we can unit-test on macOS.

import PackageDescription

let package = Package(
    name: "StudyCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "StudyCore", targets: ["StudyCore"]),
    ],
    targets: [
        .target(name: "Models", path: "Sources/Models"),
        .target(
            name: "PlannerCalendar",
            dependencies: ["Models"],
            path: "Sources/PlannerCalendar"
        ),
        .target(
            name: "TimerEngine",
            dependencies: ["Models", "PlannerCalendar"],
            path: "Sources/TimerEngine"
        ),
        .target(
            name: "BackgroundGuard",
            dependencies: [],
            path: "Sources/BackgroundGuard"
        ),
        .target(
            name: "MascotEngine",
            dependencies: ["Models"],
            path: "Sources/MascotEngine"
        ),
        .target(
            name: "PlantFormula",
            dependencies: [],
            path: "Sources/PlantFormula"
        ),
        .target(
            name: "StudyCore",
            dependencies: [
                "Models",
                "PlannerCalendar",
                "TimerEngine",
                "BackgroundGuard",
                "MascotEngine",
                "PlantFormula",
            ],
            path: "Sources/StudyCore"
        ),
        .testTarget(
            name: "StudyCoreTests",
            dependencies: ["StudyCore"],
            path: "Tests/StudyCoreTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
