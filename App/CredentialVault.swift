import Foundation
import Security

enum CredentialVault {
    private static let service = "dev.ios16reconstruction.chat.credentials"
    private static let account = "openai-api-key"
    static func readAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    @discardableResult static func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8), !key.isEmpty else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Never erase a usable API key before ensuring its replacement can
        // be written. Keep this credential unavailable while the phone locks.
        let result = SecItemUpdate(query as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if result == errSecSuccess {
            _ = SecItemUpdate(query as CFDictionary,
                [kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
                    as CFDictionary)
            return true
        }
        guard result == errSecItemNotFound else { return false }
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }
    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
