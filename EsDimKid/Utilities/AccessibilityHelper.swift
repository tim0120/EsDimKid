import AppKit
import os.log

enum AccessibilityHelper {
    private static let logger = Logger.app

    static var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func checkPermissions(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted && prompt {
            logger.warning("EsDimKid needs Accessibility permissions to track active windows.")
        }

        return trusted
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
