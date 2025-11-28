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
                "Models/ResizeHandle.swift",
                "Models/MockRecording.swift",
                "Models/KeyboardShortcut.swift",
                "Services/Settings/RegionSelectionStore.swift",
                "Services/Settings/SettingsManager.swift",
                "Services/Permissions/PermissionManager.swift",
                "Services/StatusBar/StatusBarController.swift",
                "Services/WindowDetection/WindowDetectionService.swift",
                "Services/Keyboard/KeyboardShortcutManager.swift",
                "Services/FileManager/FileManagerService.swift",
                "Services/Recording/ScreenCaptureEngine.swift",
                "Services/Recording/VideoEncoder.swift",
                "Extensions/Notification+Names.swift",
                "ViewModels/RegionSelectionViewModel.swift",
                "ViewModels/TrimDialogViewModel.swift",
                "ViewModels/PreviewDialogViewModel.swift",
                "ViewModels/HomePageViewModel.swift",
                "Windows/RegionSelectionWindow.swift",
                "Windows/SettingsWindowController.swift",
                "Windows/PreviewDialogWindowController.swift",
                "Windows/TrimDialogWindowController.swift",
                "Windows/HomePageWindowController.swift",
                "Views/RegionSelection/RegionSelectionView.swift",
                "Views/Preview/PreviewDialogView.swift",
                "Views/Trim/TrimDialogView.swift",
                "Views/Home/HomePageView.swift",
                "Views/RegionSelection/ResizeHandleView.swift",
                "Views/RegionSelection/CountdownOverlay.swift",
                "Views/Settings/SettingsBarView.swift",
                "Views/Settings/SettingsDialogView.swift",
                "Views/Components/AudioLevelIndicator.swift",
                "Views/Components/KeyboardShortcutRecorder.swift"
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
            path: "Tests/MyRecTests"
        ),
    ]
)
