import AppKit
import Combine

/// Observes when the user clicks on the desktop (Finder with no windows)
/// to auto-reveal by disabling dimming
@MainActor
class DesktopObserver {
    @Published var isDesktopActive = false

    var onDesktopActiveChanged: ((Bool) -> Void)?

    init() {
        // Observe frontmost app changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFrontmostAppChanged(notification)
            }
        }
    }

    private func handleFrontmostAppChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let isFinderWithNoWindows = checkIfFinderWithNoWindows(app)

        if isFinderWithNoWindows && !isDesktopActive {
            // User clicked on desktop
            isDesktopActive = true
            onDesktopActiveChanged?(true)
        } else if !isFinderWithNoWindows && isDesktopActive {
            // User clicked away from desktop
            isDesktopActive = false
            onDesktopActiveChanged?(false)
        }
    }

    private func checkIfFinderWithNoWindows(_ app: NSRunningApplication) -> Bool {
        guard app.bundleIdentifier == "com.apple.finder" else {
            return false
        }

        // Use Accessibility API to check if Finder has any visible windows
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return true // Assume no windows if we can't query
        }

        // Filter out minimized windows and check if any visible windows exist
        for window in windows {
            var minimizedRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)

            let isMinimized = (minimizedRef as? Bool) ?? false
            if !isMinimized {
                // There's at least one non-minimized window
                return false
            }
        }

        return true // No visible windows
    }
}
