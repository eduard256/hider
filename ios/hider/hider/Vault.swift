//
//  Vault.swift
//  hider
//
//  Зашифрованное хранилище. Случайный мастер-ключ шифрует данные (AES-GCM);
//  сам ключ хранится обёрнутым паролем (файл meta) и в Keychain за биометрией.
//

import Foundation
import Combine
import CryptoKit
import os

private let log = Logger(subsystem: "com.webaweba.hider", category: "vault")

@MainActor
final class Vault: ObservableObject {
    enum State { case needsSetup, locked, unlocked }

    @Published private(set) var state: State = .locked

    private var masterKey: SymmetricKey?

    // MARK: - Пути

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("vault", isDirectory: true)
    }
    private static var metaURL: URL { directory.appendingPathComponent("meta") }
    private static var itemsURL: URL { directory.appendingPathComponent("items", isDirectory: true) }

    /// meta-файл: salt (16 байт) + мастер-ключ, зашифрованный ключом из пароля
    private struct Meta: Codable {
        let salt: Data
        let wrappedMasterKey: Data
    }

    init() {
        state = FileManager.default.fileExists(atPath: Self.metaURL.path)
            ? .locked : .needsSetup
    }

    // MARK: - Создание

    func create(password: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.itemsURL, withIntermediateDirectories: true)

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        let salt = VaultCrypto.randomSalt()
        let passwordKey = VaultCrypto.deriveKey(password: password, salt: salt)
        let wrapped = try VaultCrypto.seal(keyData, with: passwordKey)

        let meta = Meta(salt: salt, wrappedMasterKey: wrapped)
        try JSONEncoder().encode(meta).write(to: Self.metaURL, options: .completeFileProtection)

        if !KeychainStore.saveMasterKey(keyData) {
            log.warning("master key not saved to keychain; password-only unlock")
        }

        masterKey = key
        state = .unlocked
        log.info("vault created")
    }

    // MARK: - Разблокировка

    func unlockWithBiometrics() async {
        let keyData = await Task.detached { @Sendable in KeychainStore.loadMasterKey() }.value
        guard let keyData else { return }
        masterKey = SymmetricKey(data: keyData)
        state = .unlocked
        log.info("unlocked via biometrics")
    }

    func unlockWithPassword(_ password: String) -> Bool {
        guard let metaData = try? Data(contentsOf: Self.metaURL),
              let meta = try? JSONDecoder().decode(Meta.self, from: metaData) else {
            log.error("meta unreadable")
            return false
        }
        let passwordKey = VaultCrypto.deriveKey(password: password, salt: meta.salt)
        guard let keyData = try? VaultCrypto.open(meta.wrappedMasterKey, with: passwordKey) else {
            log.warning("wrong password")
            return false
        }
        // Ключ мог не попасть в Keychain при создании — чиним по пути
        KeychainStore.saveMasterKey(keyData)
        masterKey = SymmetricKey(data: keyData)
        state = .unlocked
        log.info("unlocked via password")
        return true
    }

    func lock() {
        masterKey = nil
        state = .locked
    }

    // MARK: - Данные (всё в приложении пишется только сюда)

    func save(_ data: Data, name: String) throws {
        guard let masterKey else { throw VaultError.locked }
        let sealed = try VaultCrypto.seal(data, with: masterKey)
        try sealed.write(to: Self.itemsURL.appendingPathComponent(name),
                         options: .completeFileProtection)
    }

    func load(name: String) throws -> Data {
        guard let masterKey else { throw VaultError.locked }
        let sealed = try Data(contentsOf: Self.itemsURL.appendingPathComponent(name))
        return try VaultCrypto.open(sealed, with: masterKey)
    }

    func list() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: Self.itemsURL.path)) ?? []
    }

    func delete(name: String) throws {
        try FileManager.default.removeItem(at: Self.itemsURL.appendingPathComponent(name))
    }

    enum VaultError: Error { case locked }
}
