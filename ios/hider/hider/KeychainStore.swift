//
//  KeychainStore.swift
//  hider
//
//  Мастер-ключ в Keychain под защитой биометрии.
//  Чтение автоматически показывает Face ID / Touch ID.
//

import Foundation
import LocalAuthentication
import Security
import os

private nonisolated let log = Logger(subsystem: "com.webaweba.hider", category: "keychain")

nonisolated enum KeychainStore {
    private static let service = "com.webaweba.hider.masterkey"
    private static let account = "vault"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    /// Сохранить ключ, доступный только после биометрии/кода устройства
    @discardableResult
    static func saveMasterKey(_ key: Data) -> Bool {
        SecItemDelete(baseQuery as CFDictionary)

        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        ) else {
            log.error("access control failed: \(String(describing: error?.takeRetainedValue()))")
            return false
        }

        var query = baseQuery
        query[kSecValueData as String] = key
        query[kSecAttrAccessControl as String] = access

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess { log.error("keychain save failed: \(status)") }
        return status == errSecSuccess
    }

    /// Прочитать ключ — система сама покажет Face ID
    static func loadMasterKey() -> Data? {
        let context = LAContext()
        context.localizedReason = "Unlock hider"
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecUserCanceled { log.warning("keychain load failed: \(status)") }
            return nil
        }
        return data
    }

    static func deleteMasterKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
