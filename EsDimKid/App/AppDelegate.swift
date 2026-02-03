import AppKit
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var windowObserver: WindowObserver?
    private var desktopObserver: DesktopObserver?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions
        checkAccessibilityPermissions()

        // Initialize the overlay controller
        overlayController = OverlayWindowController()

        // Initialize the window observer
        windowObserver = WindowObserver()

        // Initialize desktop observer for auto-reveal
        desktopObserver = DesktopObserver.shared

        // Setup hotkey manager
        setupHotkeyManager()

        // Subscribe to active window changes
        windowObserver?.$activeWindowFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                self?.overlayController?.updateMask(for: frame)
            }
            .store(in: &cancellables)

        // Subscribe to dimming style changes (isEnabled is now derived from dimmingStyle)
        DimmingManager.shared.$dimmingStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                let enabled = style != .none
                if enabled {
                    self?.overlayController?.show()
                    self?.windowObserver?.startObserving()
                } else {
                    self?.overlayController?.hide()
                    self?.windowObserver?.stopObserving()
                }
                self?.overlayController?.setDimmingStyle(style)
            }
            .store(in: &cancellables)

        DimmingManager.shared.$intensity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] intensity in
                self?.overlayController?.setIntensity(intensity)
            }
            .store(in: &cancellables)

        DimmingManager.shared.$color
            .receive(on: DispatchQueue.main)
            .sink { [weak self] color in
                self?.overlayController?.setColor(color)
            }
            .store(in: &cancellables)

        DimmingManager.shared.$animationDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.overlayController?.animationDuration = duration
            }
            .store(in: &cancellables)

        DimmingManager.shared.$highlightMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.windowObserver?.highlightMode = mode
            }
            .store(in: &cancellables)

        DimmingManager.shared.$blurRadius
            .receive(on: DispatchQueue.main)
            .sink { [weak self] radius in
                self?.overlayController?.setBlurRadius(radius)
            }
            .store(in: &cancellables)

        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.overlayController?.updateForScreenChanges()
            }
        }

        // Listen for appearance changes
        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                DimmingManager.shared.applyAppearanceSettings()
            }
        }

        // Start if enabled by default
        if DimmingManager.shared.isEnabled {
            overlayController?.show()
            windowObserver?.startObserving()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowObserver?.stopObserving()
        overlayController?.hide()
    }

    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            // Will prompt user automatically due to the option above
            print("EsDimKid needs Accessibility permissions to track active windows.")
        }
    }

    private func setupHotkeyManager() {
        // Register the global hotkey
        let shortcut = DimmingManager.shared.globalShortcut
        HotkeyManager.shared.registerGlobalHotkey(
            key: shortcut.key,
            modifiers: shortcut.modifiers
        )

        // Set up toggle callback
        HotkeyManager.shared.onToggle = {
            Task { @MainActor in
                DimmingManager.shared.toggle()
            }
        }

        // Start fn key monitoring if enabled
        if DimmingManager.shared.fnKeyDisables {
            HotkeyManager.shared.startFnKeyMonitoring()
        }

        // Subscribe to fn key setting changes
        DimmingManager.shared.$fnKeyDisables
            .receive(on: DispatchQueue.main)
            .sink { enabled in
                Task { @MainActor in
                    if enabled {
                        HotkeyManager.shared.startFnKeyMonitoring()
                    } else {
                        HotkeyManager.shared.stopFnKeyMonitoring()
                    }
                }
            }
            .store(in: &cancellables)

        // Subscribe to shortcut changes
        DimmingManager.shared.$globalShortcut
            .receive(on: DispatchQueue.main)
            .sink { shortcut in
                HotkeyManager.shared.registerGlobalHotkey(
                    key: shortcut.key,
                    modifiers: shortcut.modifiers
                )
            }
            .store(in: &cancellables)
    }
}
