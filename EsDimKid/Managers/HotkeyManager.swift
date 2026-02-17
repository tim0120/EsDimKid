import AppKit
import Carbon
import os.log

/// Manages global keyboard shortcuts and fn key monitoring
@MainActor
class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventMonitor: Any?
    private var fnKeyMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private let logger = Logger.hotkey

    private var isFnKeyPressed = false

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
            logger.error("Unknown key: \(key)")
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
            logger.error("Failed to register hotkey: \(status)")
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
            // Notify coordinator via callback - it handles the state management
            onFnKeyStateChanged?(fnKeyNow)
        }
    }

    // MARK: - Key Code Mapping

    nonisolated private func keyCodeFor(key: String) -> Int? {
        ShortcutKeyMapper.keyCodeFor(key: key)
    }
}

// MARK: - Shortcut Key Mapper

enum ShortcutKeyMapper {
    static let keycodeToKey: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
        38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "n", 46: "m", 47: ".", 49: " ", 50: "`",
        36: "return", 48: "tab", 51: "delete", 53: "escape",
        123: "left", 124: "right", 125: "down", 126: "up",
        122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
        98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12",
    ]

    static let keyToKeycode: [String: Int] = {
        var map: [String: Int] = [:]
        for (code, key) in keycodeToKey {
            map[key] = Int(code)
        }
        return map
    }()

    static let validKeys: Set<String> = Set(keycodeToKey.values)

    static func isValidKey(_ key: String) -> Bool {
        validKeys.contains(key.lowercased())
    }

    static func keyString(from keycode: UInt16) -> String? {
        keycodeToKey[keycode]
    }

    static func keyCodeFor(key: String) -> Int? {
        keyToKeycode[key.lowercased()]
    }
}
