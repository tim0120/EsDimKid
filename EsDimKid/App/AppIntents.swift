import AppIntents
import SwiftUI

// MARK: - Toggle Dimming Intent

@available(macOS 14.0, *)
struct ToggleDimmingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Dimming"
    static var description = IntentDescription("Toggles the window dimming on or off")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            DimmingManager.shared.toggle()
        }
        return .result()
    }
}

// MARK: - Enable Dimming Intent

@available(macOS 14.0, *)
struct EnableDimmingIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Dimming"
    static var description = IntentDescription("Enables window dimming")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            // If currently off, enable with dim style
            if DimmingManager.shared.dimmingStyle == .none {
                DimmingManager.shared.dimmingStyle = .dim
            }
        }
        return .result()
    }
}

// MARK: - Disable Dimming Intent

@available(macOS 14.0, *)
struct DisableDimmingIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Dimming"
    static var description = IntentDescription("Disables window dimming")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            DimmingManager.shared.dimmingStyle = .none
        }
        return .result()
    }
}

// MARK: - Set Intensity Intent

@available(macOS 14.0, *)
struct SetIntensityIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Dimming Intensity"
    static var description = IntentDescription("Sets the dimming intensity (0-100%)")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Intensity", description: "Dimming intensity from 0 to 100", default: 35)
    var intensity: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set dimming intensity to \(\.$intensity)%")
    }

    func perform() async throws -> some IntentResult {
        let clampedIntensity = max(0, min(100, intensity))
        await MainActor.run {
            DimmingManager.shared.intensity = Double(clampedIntensity) / 100.0
        }
        return .result()
    }
}

// MARK: - Set Color Intent

@available(macOS 14.0, *)
struct SetColorIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Dimming Color"
    static var description = IntentDescription("Sets the dimming overlay color using a hex value")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Hex Color", description: "Color in hex format (e.g., #000000 for black)")
    var hexColor: String

    static var parameterSummary: some ParameterSummary {
        Summary("Set dimming color to \(\.$hexColor)")
    }

    func perform() async throws -> some IntentResult {
        if let color = NSColor(hex: hexColor) {
            await MainActor.run {
                DimmingManager.shared.color = color
            }
        }
        return .result()
    }
}

// MARK: - Set Highlight Mode Intent

@available(macOS 14.0, *)
struct SetHighlightModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Highlight Mode"
    static var description = IntentDescription("Sets whether to highlight single window or all app windows")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Mode")
    var mode: HighlightModeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Set highlight mode to \(\.$mode)")
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            DimmingManager.shared.highlightMode = mode.highlightMode
        }
        return .result()
    }
}

// MARK: - Highlight Mode Entity

@available(macOS 14.0, *)
struct HighlightModeEntity: AppEntity {
    var id: String
    var displayName: String

    var highlightMode: HighlightMode {
        HighlightMode(rawValue: id) ?? .singleWindow
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Highlight Mode")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    static var defaultQuery = HighlightModeQuery()
}

@available(macOS 14.0, *)
struct HighlightModeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HighlightModeEntity] {
        identifiers.compactMap { id in
            if let mode = HighlightMode(rawValue: id) {
                return HighlightModeEntity(id: id, displayName: mode.displayName)
            }
            return nil
        }
    }

    func suggestedEntities() async throws -> [HighlightModeEntity] {
        HighlightMode.allCases.map { mode in
            HighlightModeEntity(id: mode.rawValue, displayName: mode.displayName)
        }
    }
}

// MARK: - App Shortcuts Provider

@available(macOS 14.0, *)
struct EsDimKidShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDimmingIntent(),
            phrases: [
                "Toggle \(.applicationName)",
                "Toggle dimming in \(.applicationName)",
                "Turn dimming on or off in \(.applicationName)"
            ],
            shortTitle: "Toggle Dimming",
            systemImageName: "circle.lefthalf.filled"
        )

        AppShortcut(
            intent: EnableDimmingIntent(),
            phrases: [
                "Enable \(.applicationName)",
                "Turn on \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Enable Dimming",
            systemImageName: "circle.lefthalf.filled"
        )

        AppShortcut(
            intent: DisableDimmingIntent(),
            phrases: [
                "Disable \(.applicationName)",
                "Turn off \(.applicationName)",
                "Stop \(.applicationName)"
            ],
            shortTitle: "Disable Dimming",
            systemImageName: "circle"
        )
    }
}

// MARK: - Focus Filter

@available(macOS 14.0, *)
struct EsDimKidFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set EsDimKid Behavior"
    static var description: IntentDescription? = IntentDescription("Configure EsDimKid dimming based on Focus mode")

    @Parameter(title: "Enable Dimming", default: true)
    var dimmingEnabled: Bool

    @Parameter(title: "Intensity (0-100)", default: 35)
    var intensity: Int?

    @Parameter(title: "Color (hex)")
    var colorHex: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "EsDimKid: \(dimmingEnabled ? "Enabled" : "Disabled")",
            subtitle: intensity.map { "Intensity: \($0)%" } ?? nil
        )
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            // Enable/disable via dimmingStyle
            if dimmingEnabled {
                if DimmingManager.shared.dimmingStyle == .none {
                    DimmingManager.shared.dimmingStyle = .dim
                }
            } else {
                DimmingManager.shared.dimmingStyle = .none
            }

            if let intensityValue = intensity {
                let clamped = max(0, min(100, intensityValue))
                DimmingManager.shared.intensity = Double(clamped) / 100.0
            }

            if let hex = colorHex, let color = NSColor(hex: hex) {
                DimmingManager.shared.color = color
            }
        }
        return .result()
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: CGFloat
        switch hexSanitized.count {
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
