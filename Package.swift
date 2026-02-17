// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EsDimKid",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "EsDimKid",
            path: "EsDimKid",
            exclude: ["Resources/Assets.xcassets", "Info.plist", "EsDimKid.entitlements"],
            sources: [
                "App/EsDimKidApp.swift",
                "App/AppDelegate.swift",
                "App/AppIntents.swift",
                "Views/MenuBarView.swift",
                "Views/SettingsView.swift",
                "Managers/DimmingManager.swift",
                "Managers/WindowObserver.swift",
                "Managers/OverlayWindowController.swift",
                "Managers/HotkeyManager.swift",
                "Managers/DesktopObserver.swift",
                "Managers/SettingsPersistence.swift",
                "Managers/SettingsValidation.swift",
                "Models/Settings.swift",
                "Utilities/PrivateAPIs.swift",
                "Utilities/Logging.swift",
                "Utilities/AccessibilityHelper.swift",
                "Coordination/DimmingCoordinator.swift",
            ]
        )
    ]
)
