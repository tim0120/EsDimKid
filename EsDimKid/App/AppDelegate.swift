import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: DimmingCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityHelper.checkPermissions(prompt: true)
        coordinator = DimmingCoordinator()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.shutdown()
    }
}
