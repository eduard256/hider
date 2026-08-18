//
//  ChatCrypto.swift
//  hider
//
//  Криптография чатов. Только стандартные алгоритмы — схема воспроизводима
//  на любой платформе (Android: javax.crypto один в один):
//
//  • Короткий ключ чата: 16 символов Crockford Base32 (80 бит).
//  • Ключ шифрования: PBKDF2-SHA256(короткий ключ, salt="hidr1.chat",
//    600 000 итераций) → 32 байта.
//  • keyID: первые 4 байта SHA-256(ключ шифрования).
//  • Сообщение: "hidr1." + base64url(keyID(4) | nonce(12) | ciphertext | tag(16)),
//    шифр AES-256-GCM, base64url без паддинга.
//

import Foundation
import CryptoKit
import CommonCrypto

nonisolated enum ChatCrypto {
    static let prefix = "hidr1."
    static let shortKeyLength = 16
    static let iterations = 600_000
    static let salt = Data("hidr1.chat".utf8)

    // Crockford Base32: без I, L, O, U
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    enum CryptoError: Error {
        case badFormat, wrongKey, badKeyCharacters
    }

    // MARK: - Короткий ключ

    static func generateShortKey() -> String {
        var bytes = [UInt8](repeating: 0, count: shortKeyLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, shortKeyLength, &bytes)
        precondition(status == errSecSuccess, "random generation failed")
        // 256 % 32 == 0 — распределение равномерное
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }

    /// Приводим ввод пользователя к каноничному виду (Crockford: I,L→1, O→0)
    static func normalizeShortKey(_ input: String) throws -> String {
        let mapped = input.uppercased().compactMap { char -> Character? in
            switch char {
            case "I", "L": "1"
            case "O": "0"
            case "-", " ": nil
            default: char
            }
        }
        guard mapped.count == shortKeyLength,
              mapped.allSatisfy({ alphabet.contains($0) }) else {
            throw CryptoError.badKeyCharacters
        }
        return String(mapped)
    }

    // MARK: - Вывод ключа

    static func deriveKey(shortKey: String) -> Data {
        let password = Data(shortKey.utf8)
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                password.withUnsafeBytes { passPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32)
                }
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 failed: \(status)")
        return derived
    }

    static func keyID(_ key: Data) -> Data {
        Data(SHA256.hash(data: key).prefix(4))
    }

    // MARK: - Сообщения

    static func encrypt(_ text: String, key: Data) -> String {
        let sealed = try! AES.GCM.seal(Data(text.utf8), using: SymmetricKey(data: key))
        var payload = keyID(key)
        payload.append(sealed.nonce.withUnsafeBytes { Data($0) })
        payload.append(sealed.ciphertext)
        payload.append(sealed.tag)
        return prefix + base64urlEncode(payload)
    }

    static func decrypt(_ blob: String, key: Data) throws -> String {
        guard let payload = payload(of: blob), payload.count > 4 + 12 + 16 else {
            throw CryptoError.badFormat
        }
        guard payload.prefix(4) == keyID(key) else {
            throw CryptoError.wrongKey
        }
        let nonce = try AES.GCM.Nonce(data: payload.subdata(in: 4..<16))
        let ciphertext = payload.subdata(in: 16..<(payload.count - 16))
        let tag = payload.suffix(16)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        guard let opened = try? AES.GCM.open(box, using: SymmetricKey(data: key)),
              let text = String(data: opened, encoding: .utf8) else {
            throw CryptoError.wrongKey
        }
        return text
    }

    /// keyID из блоба — чтобы найти чат без расшифровки
    static func extractKeyID(_ blob: String) -> Data? {
        guard let payload = payload(of: blob), payload.count > 4 else { return nil }
        return payload.prefix(4)
    }

    static func isMessage(_ string: String) -> Bool {
        string.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(prefix)
    }

    // MARK: - base64url (без паддинга)

    private static func payload(of blob: String) -> Data? {
        let trimmed = blob.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { return nil }
        return base64urlDecode(String(trimmed.dropFirst(prefix.count)))
    }

    static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64urlDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}
