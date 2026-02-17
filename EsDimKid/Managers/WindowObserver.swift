import AppKit
import ApplicationServices
import Combine
import os.log

/// Observes the currently active window using the Accessibility API
@MainActor
class WindowObserver: ObservableObject {
    @Published var activeWindowFrame: CGRect?
    @Published var activeWindowFrames: [CGRect] = []
    @Published var activeAppBundleID: String?

    var highlightMode: HighlightMode = .singleWindow

    private var axObserver: AXObserver?
    private var currentApp: NSRunningApplication?
    private var isObserving = false
    private var debounceWorkItem: DispatchWorkItem?
    private let logger = Logger.windowObserver

    // Notifications to observe
    private let notifications: [String] = [
        kAXFocusedWindowChangedNotification as String,
        kAXMainWindowChangedNotification as String,
        kAXWindowMovedNotification as String,
        kAXWindowResizedNotification as String,
        kAXWindowCreatedNotification as String,
    ]

    init() {
        // Observe app activation changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleActiveAppDidChange(notification)
            }
        }
    }

    // MARK: - Public Methods

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        // Get the current frontmost app
        if let app = NSWorkspace.shared.frontmostApplication {
            setupObserver(for: app)
        }

        updateActiveWindowFrame()
    }

    func stopObserving() {
        isObserving = false
        removeCurrentObserver()
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    // MARK: - Private Methods

    private func handleActiveAppDidChange(_ notification: Notification) {
        guard isObserving else { return }

        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        // Check if app is excluded
        if let bundleID = app.bundleIdentifier,
           DimmingManager.shared.isAppExcluded(bundleID) {
            activeWindowFrame = nil
            activeWindowFrames = []
            activeAppBundleID = bundleID
            return
        }

        setupObserver(for: app)

        // Update immediately - no debounce for app switches
        updateActiveWindowFrame()
    }

    private func setupObserver(for app: NSRunningApplication) {
        // Remove existing observer
        removeCurrentObserver()

        currentApp = app
        activeAppBundleID = app.bundleIdentifier

        let pid = app.processIdentifier

        // Create AX observer with proper refcon handling
        var observer: AXObserver?
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let result = AXObserverCreate(pid, { _, _, _, refcon in
            // This callback runs on the main thread due to run loop source
            guard let refcon = refcon else { return }
            let observer = Unmanaged<WindowObserver>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                observer.handleAXNotification()
            }
        }, &observer)

        guard result == .success, let observer = observer else {
            logger.error("Failed to create AXObserver for pid \(pid)")
            return
        }

        self.axObserver = observer

        // Get the AXUIElement for the app
        let appElement = AXUIElementCreateApplication(pid)

        // Add notifications
        for notification in notifications {
            AXObserverAddNotification(observer, appElement, notification as CFString, refcon)
        }

        // Add observer to run loop
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }

    private func handleAXNotification() {
        // Update immediately for snappier response
        // Debouncing removed - the UI can handle rapid updates
        updateActiveWindowFrame()
    }

    private func removeCurrentObserver() {
        guard let observer = axObserver, let app = currentApp else { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Remove notifications
        for notification in notifications {
            AXObserverRemoveNotification(observer, appElement, notification as CFString)
        }

        // Remove from run loop
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        axObserver = nil
        currentApp = nil
    }

    func updateActiveWindowFrame() {
        guard isObserving else { return }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            activeWindowFrame = nil
            activeWindowFrames = []
            return
        }

        // Check if app is excluded
        if let bundleID = app.bundleIdentifier,
           DimmingManager.shared.isAppExcluded(bundleID) {
            activeWindowFrame = nil
            activeWindowFrames = []
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        switch highlightMode {
        case .singleWindow:
            activeWindowFrame = getFocusedWindowFrame(for: appElement)
            activeWindowFrames = activeWindowFrame.map { [$0] } ?? []

        case .allAppWindows:
            activeWindowFrames = getAllWindowFrames(for: appElement)
            activeWindowFrame = activeWindowFrames.first
        }
    }

    private func getFocusedWindowFrame(for appElement: AXUIElement) -> CGRect? {
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let window = focusedWindow else {
            // Fallback to main window
            return getMainWindowFrame(for: appElement)
        }

        // CFTypeRef is type-erased, so we trust the AX API returns correct type
        // swiftlint:disable:next force_cast
        return getWindowFrame(for: window as! AXUIElement)
    }

    private func getMainWindowFrame(for appElement: AXUIElement) -> CGRect? {
        var mainWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindow)

        guard result == .success, let window = mainWindow else {
            return nil
        }

        // CFTypeRef is type-erased, so we trust the AX API returns correct type
        // swiftlint:disable:next force_cast
        return getWindowFrame(for: window as! AXUIElement)
    }

    private func getAllWindowFrames(for appElement: AXUIElement) -> [CGRect] {
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        return windows.compactMap { getWindowFrame(for: $0) }
    }

    private func getWindowFrame(for window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        // CFTypeRef is type-erased, so we trust the AX API returns correct types
        // swiftlint:disable:next force_cast
        let positionValue = positionRef as! AXValue
        // swiftlint:disable:next force_cast
        let sizeValue = sizeRef as! AXValue

        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        // AX coordinates have origin at top-left of main screen
        // Convert to screen coordinates (origin at bottom-left)
        if let mainScreen = NSScreen.screens.first {
            let screenHeight = mainScreen.frame.height
            position.y = screenHeight - position.y - size.height
        }

        return CGRect(origin: position, size: size)
    }
}
