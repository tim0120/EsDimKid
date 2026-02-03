import AppKit
import SwiftUI

// MARK: - Enums

enum HighlightMode: String, Codable, CaseIterable {
    case singleWindow = "singleWindow"
    case allAppWindows = "allAppWindows"

    var displayName: String {
        switch self {
        case .singleWindow: return "Single Window"
        case .allAppWindows: return "All App Windows"
        }
    }
}

enum DimmingStyle: String, Codable, CaseIterable {
    case none = "none"
    case dim = "dim"
    case blur = "blur"
    case dimAndBlur = "dimAndBlur"

    var displayName: String {
        switch self {
        case .none: return "Off"
        case .dim: return "Dim Only"
        case .blur: return "Blur Only"
        case .dimAndBlur: return "Dim + Blur"
        }
    }
}

enum DisplayMode: String, Codable, CaseIterable {
    case perDisplay = "perDisplay"
    case dimSecondary = "dimSecondary"

    var displayName: String {
        switch self {
        case .perDisplay: return "Highlight on each display"
        case .dimSecondary: return "Dim secondary displays"
        }
    }
}

// MARK: - Codable Color

struct CodableColor: Codable, Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let black = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.red = converted.redComponent
        self.green = converted.greenComponent
        self.blue = converted.blueComponent
        self.alpha = converted.alphaComponent
    }
}

// MARK: - Appearance Settings

struct AppearanceSettings: Codable, Equatable {
    var intensity: Double
    var color: CodableColor
}

// MARK: - Keyboard Shortcut

struct KeyboardShortcutConfig: Codable, Equatable {
    var key: String
    var modifiers: [String]

    static let `default` = KeyboardShortcutConfig(
        key: "d",
        modifiers: ["control", "option", "command"]
    )
}

// MARK: - UserDefaults Keys

enum SettingsKey: String {
    case isEnabled
    case intensity
    case color
    case animationDuration
    case highlightMode
    case displayMode
    case dimmingStyle
    case blurRadius
    case fnKeyDisables
    case launchAtLogin
    case showInMenuBar
    case globalShortcut
    case excludedBundleIDs
    case useSeparateAppearanceSettings
    case lightModeSettings
    case darkModeSettings
}
