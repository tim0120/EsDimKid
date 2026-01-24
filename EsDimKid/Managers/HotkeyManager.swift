import AppKit
import Carbon

/// Manages global keyboard shortcuts and fn key monitoring
@MainActor
class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventMonitor: Any?
    private var fnKeyMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?

    private var isFnKeyPressed = false
    private var wasEnabledBeforeFn = false

    var onToggle: (() -> Void)?
    var onFnKeyStateChanged: ((Bool) -> Void)?

    private init() {}

    // MARK: - Global Hotkey

    nonisolated func registerGlobalHotkey(key: String, modifiers: [String]) {
        Task { @MainActor in
            await self.doRegisterGlobalHotkey(key: key, modifiers: modifiers)
        }
    }

    private func doRegisterGlobalHotkey(key: String, modifiers: [String]) async {
        unregisterGlobalHotkeySync()

        // Convert modifiers to Carbon format
        var carbonModifiers: UInt32 = 0
        for mod in modifiers {
            switch mod.lowercased() {
            case "command", "cmd": carbonModifiers |= UInt32(cmdKey)
            case "option", "alt": carbonModifiers |= UInt32(optionKey)
            case "control", "ctrl": carbonModifiers |= UInt32(controlKey)
            case "shift": carbonModifiers |= UInt32(shiftKey)
            default: break
            }
        }

        // Convert key to keycode
        guard let keyCode = keyCodeFor(key: key) else {
            print("Unknown key: \(key)")
            return
        }

        // Register the hotkey
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4553444B) // "ESDK" - EsDimKid
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Install event handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                Task { @MainActor in
                    HotkeyManager.shared.onToggle?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        // Register the hotkey
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
    }

    func unregisterGlobalHotkey() {
        unregisterGlobalHotkeySync()
    }

    private func unregisterGlobalHotkeySync() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Fn Key Monitoring

    func startFnKeyMonitoring() {
        guard fnKeyMonitor == nil else { return }

        fnKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
    }

    func stopFnKeyMonitoring() {
        if let monitor = fnKeyMonitor {
            NSEvent.removeMonitor(monitor)
            fnKeyMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let fnKeyNow = event.modifierFlags.contains(.function)

        if fnKeyNow != isFnKeyPressed {
            isFnKeyPressed = fnKeyNow
            onFnKeyStateChanged?(fnKeyNow)

            if fnKeyNow {
                // fn key pressed - temporarily disable dimming
                wasEnabledBeforeFn = DimmingManager.shared.isEnabled
                if wasEnabledBeforeFn {
                    DimmingManager.shared.isEnabled = false
                }
            } else {
                // fn key released - restore previous state
                if wasEnabledBeforeFn {
                    DimmingManager.shared.isEnabled = true
                }
            }
        }
    }

    // MARK: - Key Code Mapping

    nonisolated private func keyCodeFor(key: String) -> Int? {
        let keyMap: [String: Int] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, " ": 49,
            "return": 36, "tab": 48, "delete": 51, "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        ]
        return keyMap[key.lowercased()]
    }
}
