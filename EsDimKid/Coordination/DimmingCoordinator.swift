import AppKit
import Combine
import os.log

/// Central coordinator that manages all dimming-related components and their interactions.
/// Owns Combine subscriptions, component instances, and mediates callbacks.
@MainActor
final class DimmingCoordinator {
    // MARK: - Components

    private let overlayController: OverlayWindowController
    private let windowObserver: WindowObserver
    private let desktopObserver: DesktopObserver
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger.coordinator

    // MARK: - Temporary Disable State

    private var styleBeforeFn: DimmingStyle?
    private var styleBeforeDesktop: DimmingStyle?

    // MARK: - Initialization

    init() {
        overlayController = OverlayWindowController()
        windowObserver = WindowObserver()
        desktopObserver = DesktopObserver()

        setupSubscriptions()
        setupComponentCallbacks()
        setupNotificationObservers()
        setupHotkeyManager()

        // Start if enabled by default
        if DimmingManager.shared.isEnabled {
            overlayController.show()
            windowObserver.startObserving()
        }
    }

    // MARK: - Shutdown

    func shutdown() {
        windowObserver.stopObserving()
        overlayController.hide()
        cancellables.removeAll()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        let manager = DimmingManager.shared

        // Subscribe to active window changes
        windowObserver.$activeWindowFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                self?.overlayController.updateMask(for: frame)
            }
            .store(in: &cancellables)

        // Subscribe to dimming style changes
        manager.$dimmingStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                let enabled = style.isEnabled
                if enabled {
                    self?.overlayController.show()
                    self?.windowObserver.startObserving()
                } else {
                    self?.overlayController.hide()
                    self?.windowObserver.stopObserving()
                }
                self?.overlayController.setDimmingStyle(style)
            }
            .store(in: &cancellables)

        manager.$intensity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] intensity in
                self?.overlayController.setIntensity(intensity)
            }
            .store(in: &cancellables)

        manager.$color
            .receive(on: DispatchQueue.main)
            .sink { [weak self] color in
                self?.overlayController.setColor(color)
            }
            .store(in: &cancellables)

        manager.$animationDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.overlayController.animationDuration = duration
            }
            .store(in: &cancellables)

        manager.$highlightMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.windowObserver.highlightMode = mode
            }
            .store(in: &cancellables)

        manager.$blurRadius
            .receive(on: DispatchQueue.main)
            .sink { [weak self] radius in
                self?.overlayController.setBlurRadius(radius)
            }
            .store(in: &cancellables)

        manager.$fnKeyDisables
            .receive(on: DispatchQueue.main)
            .sink { enabled in
                if enabled {
                    HotkeyManager.shared.startFnKeyMonitoring()
                } else {
                    HotkeyManager.shared.stopFnKeyMonitoring()
                }
            }
            .store(in: &cancellables)

        manager.$globalShortcut
            .receive(on: DispatchQueue.main)
            .sink { shortcut in
                HotkeyManager.shared.registerGlobalHotkey(
                    key: shortcut.key,
                    modifiers: shortcut.modifiers
                )
            }
            .store(in: &cancellables)
    }

    private func setupComponentCallbacks() {
        // HotkeyManager toggle callback
        HotkeyManager.shared.onToggle = {
            Task { @MainActor in
                DimmingManager.shared.toggle()
            }
        }

        // HotkeyManager fn key state callback
        HotkeyManager.shared.onFnKeyStateChanged = { [weak self] isPressed in
            Task { @MainActor in
                self?.handleFnKeyStateChanged(isPressed)
            }
        }

        // DesktopObserver callback
        desktopObserver.onDesktopActiveChanged = { [weak self] isActive in
            Task { @MainActor in
                self?.handleDesktopActiveChanged(isActive)
            }
        }
    }

    private func setupNotificationObservers() {
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.overlayController.updateForScreenChanges()
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
    }

    private func setupHotkeyManager() {
        let shortcut = DimmingManager.shared.globalShortcut
        HotkeyManager.shared.registerGlobalHotkey(
            key: shortcut.key,
            modifiers: shortcut.modifiers
        )

        if DimmingManager.shared.fnKeyDisables {
            HotkeyManager.shared.startFnKeyMonitoring()
        }
    }

    // MARK: - Temporary Disable Handling

    private func handleFnKeyStateChanged(_ isPressed: Bool) {
        let manager = DimmingManager.shared

        if isPressed {
            // fn key pressed - temporarily disable dimming
            if manager.isEnabled {
                styleBeforeFn = manager.dimmingStyle
                manager.dimmingStyle = .none
            }
        } else {
            // fn key released - restore previous state
            if let previousStyle = styleBeforeFn {
                manager.dimmingStyle = previousStyle
                styleBeforeFn = nil
            }
        }
    }

    private func handleDesktopActiveChanged(_ isActive: Bool) {
        let manager = DimmingManager.shared

        if isActive {
            // User clicked on desktop - temporarily disable dimming
            if manager.isEnabled {
                styleBeforeDesktop = manager.dimmingStyle
                manager.dimmingStyle = .none
            }
        } else {
            // User clicked away from desktop - restore previous state
            if let previousStyle = styleBeforeDesktop {
                manager.dimmingStyle = previousStyle
                styleBeforeDesktop = nil
            }
        }
    }
}
