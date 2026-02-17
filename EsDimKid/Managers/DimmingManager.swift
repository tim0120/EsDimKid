import AppKit
import Combine
import os.log
import ServiceManagement

@MainActor
class DimmingManager: ObservableObject {
    static let shared = DimmingManager()

    private let persistence = SettingsPersistence.shared
    private let logger = Logger.dimmingManager

    // MARK: - Published Properties

    // isEnabled is now derived from dimmingStyle - true when either dim or blur is on
    var isEnabled: Bool {
        dimmingStyle != .none
    }

    @Published var intensity: Double {
        didSet {
            let validated = IntensityValidator.validate(intensity)
            if validated != intensity { intensity = validated; return }
            persistence.savePrimitive(intensity, for: .intensity)
        }
    }

    @Published var color: NSColor {
        didSet {
            do {
                try persistence.save(CodableColor(nsColor: color), for: .color)
            } catch {
                logger.error("Failed to save color: \(error.localizedDescription)")
            }
        }
    }

    @Published var animationDuration: Double {
        didSet {
            let validated = AnimationDurationValidator.validate(animationDuration)
            if validated != animationDuration { animationDuration = validated; return }
            persistence.savePrimitive(animationDuration, for: .animationDuration)
        }
    }

    @Published var highlightMode: HighlightMode {
        didSet { persistence.savePrimitive(highlightMode.rawValue, for: .highlightMode) }
    }

    @Published var displayMode: DisplayMode {
        didSet { persistence.savePrimitive(displayMode.rawValue, for: .displayMode) }
    }

    @Published var dimmingStyle: DimmingStyle {
        didSet { persistence.savePrimitive(dimmingStyle.rawValue, for: .dimmingStyle) }
    }

    @Published var blurRadius: Double {
        didSet {
            let validated = BlurRadiusValidator.validate(blurRadius)
            if validated != blurRadius { blurRadius = validated; return }
            persistence.savePrimitive(blurRadius, for: .blurRadius)
        }
    }

    @Published var fnKeyDisables: Bool {
        didSet { persistence.savePrimitive(fnKeyDisables, for: .fnKeyDisables) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            persistence.savePrimitive(launchAtLogin, for: .launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    @Published var excludedBundleIDs: Set<String> {
        didSet {
            persistence.savePrimitive(Array(excludedBundleIDs), for: .excludedBundleIDs)
        }
    }

    @Published var useSeparateAppearanceSettings: Bool {
        didSet {
            persistence.savePrimitive(useSeparateAppearanceSettings, for: .useSeparateAppearanceSettings)
            applyAppearanceSettings()
        }
    }

    @Published var lightModeSettings: AppearanceSettings {
        didSet {
            do {
                try persistence.save(lightModeSettings, for: .lightModeSettings)
            } catch {
                logger.error("Failed to save light mode settings: \(error.localizedDescription)")
            }
        }
    }

    @Published var darkModeSettings: AppearanceSettings {
        didSet {
            do {
                try persistence.save(darkModeSettings, for: .darkModeSettings)
            } catch {
                logger.error("Failed to save dark mode settings: \(error.localizedDescription)")
            }
        }
    }

    @Published var globalShortcut: KeyboardShortcutConfig {
        didSet {
            do {
                try persistence.save(globalShortcut, for: .globalShortcut)
            } catch {
                logger.error("Failed to save global shortcut: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Computed Properties

    var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    // MARK: - Initialization

    private init() {
        let persistence = SettingsPersistence.shared

        // Load saved settings or use defaults
        self.intensity = persistence.loadDouble(for: .intensity, default: 0.35)
        self.animationDuration = persistence.loadDouble(for: .animationDuration, default: 0.15)
        self.fnKeyDisables = persistence.loadBool(for: .fnKeyDisables, default: true)
        self.launchAtLogin = persistence.loadBool(for: .launchAtLogin, default: false)
        self.useSeparateAppearanceSettings = persistence.loadBool(for: .useSeparateAppearanceSettings, default: false)

        // Load color - default to near black
        if let codableColor = persistence.load(CodableColor.self, for: .color) {
            self.color = codableColor.nsColor
        } else {
            self.color = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        }

        // Load highlight mode
        if let modeString = persistence.loadString(for: .highlightMode),
           let mode = HighlightMode(rawValue: modeString) {
            self.highlightMode = mode
        } else {
            self.highlightMode = .singleWindow
        }

        // Load display mode
        if let modeString = persistence.loadString(for: .displayMode),
           let mode = DisplayMode(rawValue: modeString) {
            self.displayMode = mode
        } else {
            self.displayMode = .perDisplay
        }

        // Load dimming style
        if let styleString = persistence.loadString(for: .dimmingStyle),
           let style = DimmingStyle(rawValue: styleString) {
            self.dimmingStyle = style
        } else {
            self.dimmingStyle = .dim
        }

        // Migration: if old isEnabled was false, set style to none
        if let wasEnabled = persistence.loadOptionalBool(for: .isEnabled), !wasEnabled {
            self.dimmingStyle = .none
            persistence.remove(for: .isEnabled)
        }

        // Load blur intensity (0-1)
        self.blurRadius = persistence.loadDouble(for: .blurRadius, default: 0.5)

        // Load excluded bundle IDs
        if let bundleIDs = persistence.loadStringArray(for: .excludedBundleIDs) {
            self.excludedBundleIDs = Set(bundleIDs)
        } else {
            self.excludedBundleIDs = []
        }

        // Load appearance settings
        if let settings = persistence.load(AppearanceSettings.self, for: .lightModeSettings) {
            self.lightModeSettings = settings
        } else {
            self.lightModeSettings = AppearanceSettings(intensity: 0.35, color: .black)
        }

        if let settings = persistence.load(AppearanceSettings.self, for: .darkModeSettings) {
            self.darkModeSettings = settings
        } else {
            self.darkModeSettings = AppearanceSettings(intensity: 0.35, color: .black)
        }

        // Load global shortcut
        if let shortcut = persistence.load(KeyboardShortcutConfig.self, for: .globalShortcut) {
            self.globalShortcut = shortcut
        } else {
            self.globalShortcut = .default
        }
    }

    // MARK: - Public Methods

    /// Stores the previous style so toggle() can restore it
    private var previousStyle: DimmingStyle = .dim

    func toggle() {
        if isEnabled {
            previousStyle = dimmingStyle
            dimmingStyle = .none
        } else {
            dimmingStyle = previousStyle != .none ? previousStyle : .dim
        }
    }

    func applyAppearanceSettings() {
        guard useSeparateAppearanceSettings else { return }

        if isDarkMode {
            intensity = darkModeSettings.intensity
            color = darkModeSettings.color.nsColor
        } else {
            intensity = lightModeSettings.intensity
            color = lightModeSettings.color.nsColor
        }
    }

    func isAppExcluded(_ bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    func addExcludedApp(_ bundleID: String) {
        excludedBundleIDs.insert(bundleID)
    }

    func removeExcludedApp(_ bundleID: String) {
        excludedBundleIDs.remove(bundleID)
    }

    // MARK: - Private Methods

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to update launch at login: \(error.localizedDescription)")
        }
    }
}
