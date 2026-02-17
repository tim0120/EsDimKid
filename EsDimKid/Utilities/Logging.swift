import os.log

extension Logger {
    private static let subsystem = "com.esdimkid"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let windowObserver = Logger(subsystem: subsystem, category: "windowObserver")
    static let dimmingManager = Logger(subsystem: subsystem, category: "dimmingManager")
    static let coordinator = Logger(subsystem: subsystem, category: "coordinator")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
}
