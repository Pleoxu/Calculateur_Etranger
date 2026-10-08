import Foundation
import Security

enum SecureKeyProvider {

    private static let service = "CalculateurTirSecureAssets"
    private static let account = "asset-key-v2"

    enum SecureKeyError: LocalizedError {
        case keyNotFound(OSStatus)
        case keychainError(OSStatus)
        case invalidEncoding
        case invalidKey

        var errorDescription: String? {
            switch self {
            case .keyNotFound(let status):
                return "Clé sécurisée introuvable dans le Trousseau (status \(status))."

            case .keychainError(let status):
                return "Erreur du Trousseau (status \(status))."

            case .invalidEncoding:
                return "Impossible de décoder la clé sécurisée."

            case .invalidKey:
                return "Clé AES invalide : 64 caractères hexadécimaux attendus."
            }
        }
    }

    // MARK: - Lecture

    static func loadContentKeyHex() throws -> String {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &item
        )

        if status == errSecItemNotFound {
            throw SecureKeyError.keyNotFound(status)
        }

        guard status == errSecSuccess else {
            throw SecureKeyError.keychainError(status)
        }

        guard
            let data = item as? Data,
            let keyHex = String(data: data, encoding: .utf8)
        else {
            throw SecureKeyError.invalidEncoding
        }

        return try validate(keyHex)
    }

    // MARK: - Stockage

    static func storeContentKeyHex(_ keyHex: String) throws {

        let normalized = try validate(keyHex)

        guard let data = normalized.data(using: .utf8) else {
            throw SecureKeyError.invalidEncoding
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw SecureKeyError.keychainError(updateStatus)
        }

        var addQuery = query

        for (key, value) in attributes {
            addQuery[key] = value
        }

        let addStatus = SecItemAdd(
            addQuery as CFDictionary,
            nil
        )

        guard addStatus == errSecSuccess else {
            throw SecureKeyError.keychainError(addStatus)
        }
    }

    // MARK: - Présence

    static func hasContentKey() -> Bool {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        return SecItemCopyMatching(
            query as CFDictionary,
            nil
        ) == errSecSuccess
    }

    // MARK: - Validation

    private static func validate(_ keyHex: String) throws -> String {

        let normalized = keyHex
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            normalized.count == 64,
            normalized.allSatisfy({ $0.isHexDigit })
        else {
            throw SecureKeyError.invalidKey
        }

        return normalized.lowercased()
    }
}
