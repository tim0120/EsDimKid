import AppKit
import Combine
import ServiceManagement

@MainActor
class DimmingManager: ObservableObject {
    static let shared = DimmingManager()

    // MARK: - Published Properties

    // isEnabled is now derived from dimmingStyle - true when either dim or blur is on
    var isEnabled: Bool {
        dimmingStyle != .none
    }

    @Published var intensity: Double {
        didSet { UserDefaults.standard.set(intensity, forKey: SettingsKey.intensity.rawValue) }
    }

    @Published var color: NSColor {
        didSet {
            if let data = try? JSONEncoder().encode(CodableColor(nsColor: color)) {
                UserDefaults.standard.set(data, forKey: SettingsKey.color.rawValue)
            }
        }
    }

    @Published var animationDuration: Double {
        didSet { UserDefaults.standard.set(animationDuration, forKey: SettingsKey.animationDuration.rawValue) }
    }

    @Published var highlightMode: HighlightMode {
        didSet { UserDefaults.standard.set(highlightMode.rawValue, forKey: SettingsKey.highlightMode.rawValue) }
    }

    @Published var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: SettingsKey.displayMode.rawValue) }
    }

    @Published var dimmingStyle: DimmingStyle {
        didSet { UserDefaults.standard.set(dimmingStyle.rawValue, forKey: SettingsKey.dimmingStyle.rawValue) }
    }

    @Published var blurRadius: Double {
        didSet { UserDefaults.standard.set(blurRadius, forKey: SettingsKey.blurRadius.rawValue) }
    }

    @Published var fnKeyDisables: Bool {
        didSet { UserDefaults.standard.set(fnKeyDisables, forKey: SettingsKey.fnKeyDisables.rawValue) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: SettingsKey.launchAtLogin.rawValue)
            updateLaunchAtLogin()
        }
    }

    @Published var excludedBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(excludedBundleIDs), forKey: SettingsKey.excludedBundleIDs.rawValue)
        }
    }

    @Published var useSeparateAppearanceSettings: Bool {
        didSet {
            UserDefaults.standard.set(useSeparateAppearanceSettings, forKey: SettingsKey.useSeparateAppearanceSettings.rawValue)
            applyAppearanceSettings()
        }
    }

    @Published var lightModeSettings: AppearanceSettings {
        didSet {
            if let data = try? JSONEncoder().encode(lightModeSettings) {
                UserDefaults.standard.set(data, forKey: SettingsKey.lightModeSettings.rawValue)
            }
        }
    }

    @Published var darkModeSettings: AppearanceSettings {
        didSet {
            if let data = try? JSONEncoder().encode(darkModeSettings) {
                UserDefaults.standard.set(data, forKey: SettingsKey.darkModeSettings.rawValue)
            }
        }
    }

    @Published var globalShortcut: KeyboardShortcutConfig {
        didSet {
            if let data = try? JSONEncoder().encode(globalShortcut) {
                UserDefaults.standard.set(data, forKey: SettingsKey.globalShortcut.rawValue)
            }
        }
    }

    // MARK: - Computed Properties

    var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    // MARK: - Initialization

    private init() {
        // Load saved settings or use defaults
        self.intensity = UserDefaults.standard.object(forKey: SettingsKey.intensity.rawValue) as? Double ?? 0.35
        self.animationDuration = UserDefaults.standard.object(forKey: SettingsKey.animationDuration.rawValue) as? Double ?? 0.15  // Faster default
        self.fnKeyDisables = UserDefaults.standard.object(forKey: SettingsKey.fnKeyDisables.rawValue) as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.object(forKey: SettingsKey.launchAtLogin.rawValue) as? Bool ?? false
        self.useSeparateAppearanceSettings = UserDefaults.standard.object(forKey: SettingsKey.useSeparateAppearanceSettings.rawValue) as? Bool ?? false

        // Load color - default to near black
        if let colorData = UserDefaults.standard.data(forKey: SettingsKey.color.rawValue),
           let codableColor = try? JSONDecoder().decode(CodableColor.self, from: colorData) {
            self.color = codableColor.nsColor
        } else {
            self.color = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)  // Near black
        }

        // Load highlight mode
        if let modeString = UserDefaults.standard.string(forKey: SettingsKey.highlightMode.rawValue),
           let mode = HighlightMode(rawValue: modeString) {
            self.highlightMode = mode
        } else {
            self.highlightMode = .singleWindow
        }

        // Load display mode
        if let modeString = UserDefaults.standard.string(forKey: SettingsKey.displayMode.rawValue),
           let mode = DisplayMode(rawValue: modeString) {
            self.displayMode = mode
        } else {
            self.displayMode = .perDisplay
        }

        // Load dimming style
        if let styleString = UserDefaults.standard.string(forKey: SettingsKey.dimmingStyle.rawValue),
           let style = DimmingStyle(rawValue: styleString) {
            self.dimmingStyle = style
        } else {
            self.dimmingStyle = .dim
        }

        // Migration: if old isEnabled was false, set style to none
        if let wasEnabled = UserDefaults.standard.object(forKey: SettingsKey.isEnabled.rawValue) as? Bool,
           !wasEnabled {
            self.dimmingStyle = .none
            // Clean up old key
            UserDefaults.standard.removeObject(forKey: SettingsKey.isEnabled.rawValue)
        }

        // Load blur intensity (0-1)
        self.blurRadius = UserDefaults.standard.object(forKey: SettingsKey.blurRadius.rawValue) as? Double ?? 0.5

        // Load excluded bundle IDs
        if let bundleIDs = UserDefaults.standard.stringArray(forKey: SettingsKey.excludedBundleIDs.rawValue) {
            self.excludedBundleIDs = Set(bundleIDs)
        } else {
            self.excludedBundleIDs = []
        }

        // Load appearance settings
        if let data = UserDefaults.standard.data(forKey: SettingsKey.lightModeSettings.rawValue),
           let settings = try? JSONDecoder().decode(AppearanceSettings.self, from: data) {
            self.lightModeSettings = settings
        } else {
            self.lightModeSettings = AppearanceSettings(intensity: 0.35, color: .black)
        }

        if let data = UserDefaults.standard.data(forKey: SettingsKey.darkModeSettings.rawValue),
           let settings = try? JSONDecoder().decode(AppearanceSettings.self, from: data) {
            self.darkModeSettings = settings
        } else {
            self.darkModeSettings = AppearanceSettings(intensity: 0.35, color: .black)
        }

        // Load global shortcut
        if let data = UserDefaults.standard.data(forKey: SettingsKey.globalShortcut.rawValue),
           let shortcut = try? JSONDecoder().decode(KeyboardShortcutConfig.self, from: data) {
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
            print("Failed to update launch at login: \(error)")
        }
    }
}
