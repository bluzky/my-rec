// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyRec",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MyRec", targets: ["MyRec"]),
        .library(name: "MyRecCore", targets: ["MyRecCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MyRecCore",
            path: "MyRec",
            sources: [
                "Models/Resolution.swift",
                "Models/FrameRate.swift",
                "Models/RecordingSettings.swift",
                "Models/RecordingState.swift",
                "Models/VideoMetadata.swift",
                "Services/Settings/SettingsManager.swift",
                "Services/Permissions/PermissionManager.swift",
                "Services/StatusBar/StatusBarController.swift",
                "Extensions/Notification+Names.swift"
            ],
            cSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),
        .executableTarget(
            name: "MyRec",
            dependencies: ["MyRecCore"],
            path: "MyRec",
            sources: [
                "AppDelegate.swift",
                "MyRecApp.swift",
                "ContentView.swift"
            ]
        ),
        .testTarget(
            name: "MyRecTests",
            dependencies: [
                "MyRecCore"
            ],
            path: "MyRecTests"
        ),
    ]
)