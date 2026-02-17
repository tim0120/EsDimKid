import Foundation
import os.log

// MARK: - Protocol

protocol SettingsPersistenceProtocol {
    func save<T: Encodable>(_ value: T, for key: SettingsKey) throws
    func load<T: Decodable>(_ type: T.Type, for key: SettingsKey) -> T?
    func savePrimitive(_ value: Any, for key: SettingsKey)
    func loadDouble(for key: SettingsKey, default defaultValue: Double) -> Double
    func loadBool(for key: SettingsKey, default defaultValue: Bool) -> Bool
    func loadOptionalBool(for key: SettingsKey) -> Bool?
    func loadString(for key: SettingsKey) -> String?
    func loadStringArray(for key: SettingsKey) -> [String]?
    func remove(for key: SettingsKey)
}

// MARK: - Errors

enum SettingsPersistenceError: LocalizedError {
    case encodingFailed(key: SettingsKey, underlying: Error)
    case decodingFailed(key: SettingsKey, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let key, let error):
            return "Failed to encode value for key '\(key.rawValue)': \(error.localizedDescription)"
        case .decodingFailed(let key, let error):
            return "Failed to decode value for key '\(key.rawValue)': \(error.localizedDescription)"
        }
    }
}

// MARK: - Implementation

final class SettingsPersistence: SettingsPersistenceProtocol {
    static let shared = SettingsPersistence()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger.settings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Codable Values

    func save<T: Encodable>(_ value: T, for key: SettingsKey) throws {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key.rawValue)
        } catch {
            logger.error("Failed to encode \(key.rawValue): \(error.localizedDescription)")
            throw SettingsPersistenceError.encodingFailed(key: key, underlying: error)
        }
    }

    func load<T: Decodable>(_ type: T.Type, for key: SettingsKey) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else {
            return nil
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.warning("Failed to decode \(key.rawValue): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Primitive Values

    func savePrimitive(_ value: Any, for key: SettingsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    func loadDouble(for key: SettingsKey, default defaultValue: Double) -> Double {
        if let value = defaults.object(forKey: key.rawValue) as? Double {
            return value
        }
        return defaultValue
    }

    func loadBool(for key: SettingsKey, default defaultValue: Bool) -> Bool {
        if let value = defaults.object(forKey: key.rawValue) as? Bool {
            return value
        }
        return defaultValue
    }

    func loadOptionalBool(for key: SettingsKey) -> Bool? {
        defaults.object(forKey: key.rawValue) as? Bool
    }

    func loadString(for key: SettingsKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    func loadStringArray(for key: SettingsKey) -> [String]? {
        defaults.stringArray(forKey: key.rawValue)
    }

    func remove(for key: SettingsKey) {
        defaults.removeObject(forKey: key.rawValue)
    }
}
