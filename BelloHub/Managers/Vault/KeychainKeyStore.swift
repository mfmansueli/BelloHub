//
//  KeychainKeyStore.swift
//  BelloHub
//

import Foundation
import Security

/// The seed in iCloud Keychain (docs/06-PRIVACY-SECURITY.md section 4.2): a generic password with service
/// `app.bellohub.keys` and account `seed.v1`, synchronizable, readable after the first unlock so background sync
/// can open records. A new iPhone on the same Apple ID gets it with the Keychain, without the 12 words.
struct KeychainKeyStore: KeyStoring {
    enum Failure: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case malformedItem
    }

    var service = "app.bellohub.keys"
    var account = "seed.v1"
    var isSynchronizable = true

    func loadSeed() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw Failure.malformedItem }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw Failure.unexpectedStatus(status)
        }
    }

    func saveSeed(_ seed: Data) throws {
        var attributes = baseQuery()
        attributes[kSecValueData as String] = seed
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        attributes[kSecAttrSynchronizable as String] = isSynchronizable
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: seed] as CFDictionary)
            guard update == errSecSuccess else { throw Failure.unexpectedStatus(update) }
        } else if status != errSecSuccess {
            throw Failure.unexpectedStatus(status)
        }
    }

    func deleteSeed() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.unexpectedStatus(status) }
    }

    /// Matches the item whether or not it was synced, so a seed that arrived from another device is found.
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
