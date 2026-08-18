//
//  ChatStore.swift
//  hider
//
//  Список чатов. Хранится в vault одним зашифрованным JSON-файлом.
//

import Foundation
import Combine
import os

private let log = Logger(subsystem: "com.webaweba.hider", category: "chats")

struct Chat: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let shortKey: String   // 16 символов Crockford Base32
    let key: Data          // кэш PBKDF2 — чтобы не считать 600k итераций каждый раз
    let keyID: Data

    var formattedKey: String {
        stride(from: 0, to: shortKey.count, by: 4).map {
            let start = shortKey.index(shortKey.startIndex, offsetBy: $0)
            let end = shortKey.index(start, offsetBy: 4)
            return String(shortKey[start..<end])
        }.joined(separator: "-")
    }
}

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var chats: [Chat] = []

    private let vault: Vault
    private static let fileName = "chats.json"

    init(vault: Vault) {
        self.vault = vault
        load()
    }

    private func load() {
        guard let data = try? vault.load(name: Self.fileName) else { return }
        do {
            chats = try JSONDecoder().decode([Chat].self, from: data)
        } catch {
            log.error("chats decode failed: \(error.localizedDescription)")
        }
    }

    private func persist() {
        do {
            try vault.save(JSONEncoder().encode(chats), name: Self.fileName)
        } catch {
            log.error("chats save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Создание / подключение (PBKDF2 медленный — вне главного потока)

    func create(name: String) async -> Chat {
        let shortKey = ChatCrypto.generateShortKey()
        log.info("create: deriving key…")
        let start = Date()
        let key = await Task.detached { ChatCrypto.deriveKey(shortKey: shortKey) }.value
        log.info("create: derived in \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s")
        let chat = Chat(id: UUID(), name: name, shortKey: shortKey,
                        key: key, keyID: ChatCrypto.keyID(key))
        chats.append(chat)
        persist()
        log.info("chat created")
        return chat
    }

    /// Подключение к существующему чату по ключу (сканер или ручной ввод)
    func join(name: String, rawKey: String) async -> Chat? {
        // QR может содержать "hidr1:<ключ>"
        let cleaned = rawKey.hasPrefix("hidr1:")
            ? String(rawKey.dropFirst("hidr1:".count)) : rawKey
        guard let shortKey = try? ChatCrypto.normalizeShortKey(cleaned) else {
            log.warning("join: invalid key")
            return nil
        }
        if let existing = chats.first(where: { $0.shortKey == shortKey }) {
            return existing
        }
        log.info("join: deriving key…")
        let start = Date()
        let key = await Task.detached { ChatCrypto.deriveKey(shortKey: shortKey) }.value
        log.info("join: derived in \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s")
        // Перепроверяем после долгого PBKDF2 — защита от двойного вызова
        if let existing = chats.first(where: { $0.shortKey == shortKey }) {
            return existing
        }
        let chat = Chat(id: UUID(), name: name, shortKey: shortKey,
                        key: key, keyID: ChatCrypto.keyID(key))
        chats.append(chat)
        persist()
        log.info("chat joined")
        return chat
    }

    func delete(_ chat: Chat) {
        chats.removeAll { $0.id == chat.id }
        persist()
    }

    // MARK: - Сообщения

    func encrypt(_ text: String, for chat: Chat) -> String {
        ChatCrypto.encrypt(text, key: chat.key)
    }

    /// Находим чат по keyID блоба и расшифровываем
    func decrypt(_ blob: String) -> (chat: Chat, text: String)? {
        guard let keyID = ChatCrypto.extractKeyID(blob),
              let chat = chats.first(where: { $0.keyID == keyID }),
              let text = try? ChatCrypto.decrypt(blob, key: chat.key) else {
            return nil
        }
        return (chat, text)
    }
}
