// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Daymark",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "RoutineCore", targets: ["RoutineCore"]),
    ],
    targets: [
        .target(
            name: "RoutineCore",
            path: "RoutineCore/Sources/RoutineCore"
        ),
        .testTarget(
            name: "RoutineCoreTests",
            dependencies: ["RoutineCore"],
            path: "RoutineCore/Tests/RoutineCoreTests"
        ),
    ]
)
