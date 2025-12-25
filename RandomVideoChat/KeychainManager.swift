import Foundation
import Security

// MARK: - Keychain Manager
/// Secure storage for sensitive data using iOS Keychain Services

enum KeychainManager {

    // MARK: - Keys
    enum Key: String {
        case agoraLocalUid = "com.pukaworks.5sec.agora.localUid"
        case currentChannelName = "com.pukaworks.5sec.channel.name"
        case currentMatchId = "com.pukaworks.5sec.match.id"
        case agoraToken = "com.pukaworks.5sec.agora.token"
    }

    // MARK: - Errors
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    // MARK: - Save Operations

    /// Saves a string value to the keychain
    static func save(_ value: String, forKey key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }

    /// Saves an integer value to the keychain
    static func save(_ value: Int, forKey key: Key) -> Bool {
        let data = withUnsafeBytes(of: value) { Data($0) }
        return save(data, forKey: key)
    }

    /// Saves a UInt value to the keychain
    static func save(_ value: UInt, forKey key: Key) -> Bool {
        let data = withUnsafeBytes(of: value) { Data($0) }
        return save(data, forKey: key)
    }

    /// Saves raw data to the keychain
    static func save(_ data: Data, forKey key: Key) -> Bool {
        // First try to delete any existing item
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            #if DEBUG
            print("🔐 Keychain: Saved \(key.rawValue)")
            #endif
            return true
        } else {
            #if DEBUG
            print("❌ Keychain: Failed to save \(key.rawValue) - Status: \(status)")
            #endif
            return false
        }
    }

    // MARK: - Load Operations

    /// Loads a string value from the keychain
    static func loadString(forKey key: Key) -> String? {
        guard let data = loadData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Loads an integer value from the keychain
    static func loadInt(forKey key: Key) -> Int? {
        guard let data = loadData(forKey: key), data.count == MemoryLayout<Int>.size else { return nil }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    /// Loads a UInt value from the keychain
    static func loadUInt(forKey key: Key) -> UInt? {
        guard let data = loadData(forKey: key), data.count == MemoryLayout<UInt>.size else { return nil }
        return data.withUnsafeBytes { $0.load(as: UInt.self) }
    }

    /// Loads raw data from the keychain
    static func loadData(forKey key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            #if DEBUG
            print("🔐 Keychain: Loaded \(key.rawValue)")
            #endif
            return data
        } else {
            #if DEBUG
            if status != errSecItemNotFound {
                print("⚠️ Keychain: Failed to load \(key.rawValue) - Status: \(status)")
            }
            #endif
            return nil
        }
    }

    // MARK: - Delete Operations

    /// Deletes a value from the keychain
    @discardableResult
    static func delete(forKey key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            #if DEBUG
            print("🔐 Keychain: Deleted \(key.rawValue)")
            #endif
            return true
        } else {
            #if DEBUG
            print("❌ Keychain: Failed to delete \(key.rawValue) - Status: \(status)")
            #endif
            return false
        }
    }

    /// Deletes all app-related keychain items
    static func deleteAll() {
        Key.allCases.forEach { delete(forKey: $0) }
        #if DEBUG
        print("🔐 Keychain: All items deleted")
        #endif
    }

    // MARK: - Utility

    /// Checks if a value exists in the keychain
    static func exists(forKey key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - CaseIterable for Keys
extension KeychainManager.Key: CaseIterable {}
