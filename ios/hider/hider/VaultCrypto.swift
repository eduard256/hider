//
//  VaultCrypto.swift
//  hider
//
//  Криптография хранилища: PBKDF2 для пароля, AES-GCM для данных.
//  Мастер-ключ случайный; пароль лишь "оборачивает" его.
//

import Foundation
import CryptoKit
import CommonCrypto

enum VaultCrypto {
    static let pbkdf2Iterations = 600_000

    /// Ключ из пароля: PBKDF2-SHA256
    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                passwordData.withUnsafeBytes { passPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(pbkdf2Iterations),
                        derivedPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32)
                }
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 failed: \(status)")
        return SymmetricKey(data: derived)
    }

    static func randomSalt() -> Data {
        Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
    }

    static func seal(_ data: Data, with key: SymmetricKey) throws -> Data {
        try AES.GCM.seal(data, using: key).combined!
    }

    static func open(_ sealed: Data, with key: SymmetricKey) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
    }
}
