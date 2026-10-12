//
//  KeychainRegistrationAllowanceStore.swift
//  BelloHub
//

import Foundation
import os
import Security

/// The free-registration count in the Keychain (D59): a generic password with service `app.bellohub.registrations`
/// and account `count.v1`, holding the number as text. `AfterFirstUnlockThisDeviceOnly` and never synchronised: it
/// stays on this iPhone, is not in iCloud Keychain, and does not move to a new iPhone restored from a backup. It holds
/// no personal data, and errors are logged by status code only.
struct KeychainRegistrationAllowanceStore: RegistrationAllowanceStoring {
    var service = "app.bellohub.registrations"
    var account = "count.v1"
    private let logger = Logger(subsystem: "app.bellohub", category: "allowance")

    func load() -> Int? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let count = Int(String(decoding: data, as: UTF8.self)) else {
                logger.error("allowance item unreadable")
                return nil
            }
            return count
        case errSecItemNotFound:
            return nil
        default:
            logger.error("allowance read failed status=\(status, privacy: .public)")
            return nil
        }
    }

    func save(_ count: Int) {
        let data = Data(String(max(count, 0)).utf8)
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if update != errSecSuccess { logger.error("allowance update failed status=\(update, privacy: .public)") }
        } else if status != errSecSuccess {
            logger.error("allowance save failed status=\(status, privacy: .public)")
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
