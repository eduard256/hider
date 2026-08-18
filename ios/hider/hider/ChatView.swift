//
//  ChatView.swift
//  hider
//
//  Экран чата: результат шифрования/расшифровки над полем ввода.
//  Ввод — в нижней панели, обработка с дебаунсом — в MainView.
//

import SwiftUI

enum ChatResult: Equatable {
    case none
    case encrypted(String)
    case decrypted(String)
    case failed
}

struct ChatView: View {
    let chat: Chat
    let result: ChatResult

    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Шапка: идентикон + имя
            VStack(spacing: DS.space / 2) {
                IdenticonView(seed: chat.keyID)
                    .frame(width: 66, height: 44)
                Text(chat.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(DS.ink)
            }
            .padding(.top, DS.spaceL)

            Spacer(minLength: DS.space)

            switch result {
            case .none:
                EmptyView()

            case .encrypted(let blob):
                resultCard(icon: "lock") {
                    ScrollView {
                        Text(blob)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(DS.ink.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 220)
                } actions: {
                    copyButton(blob)
                    ShareLink(item: blob) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(DS.ink)
                    }
                    .buttonStyle(.plain)
                }

            case .decrypted(let text):
                resultCard(icon: "lock.open") {
                    ScrollView {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(DS.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 260)
                } actions: {
                    copyButton(text)
                }

            case .failed:
                VStack(spacing: DS.space) {
                    Image(systemName: "lock.slash")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(DS.ink.opacity(0.3))
                    Text("cannot decrypt")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DS.ink.opacity(0.4))
                }
            }

            Spacer(minLength: DS.space)

            // Стрелка на поле ввода
            HStack(spacing: DS.space / 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(DS.ink.opacity(0.35))
                    .padding(.leading, DS.space)
                Text("paste text to encrypt or decrypt — it will figure it out")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DS.ink.opacity(0.8))
                Spacer()
            }
            .padding(.bottom, DS.spaceL + DS.controlSize)
        }
        .animation(.bouncy(duration: 0.35), value: result)
    }

    // Карточка результата: контент + иконки действий
    private func resultCard<Content: View, Actions: View>(
        icon: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: DS.space) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(DS.ink.opacity(0.5))

            content()
                .padding(DS.space / 1.5)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.corner)
                        .stroke(DS.ink.opacity(0.25), lineWidth: DS.hairline)
                )

            HStack(spacing: DS.spaceL) {
                actions()
            }
        }
        .padding(.horizontal, DS.spaceL)
        .frame(maxWidth: 560)
        .transition(.opacity.combined(with: .offset(y: 12)))
    }

    private func copyButton(_ text: String) -> some View {
        Button {
            copyToPasteboard(text)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(DS.ink)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

func copyToPasteboard(_ string: String) {
    #if os(iOS)
    UIPasteboard.general.string = string
    #else
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
    #endif
}
