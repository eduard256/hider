//
//  LockView.swift
//  hider
//
//  Запуск: сразу Face ID; если не вышло — поле пароля.
//

import SwiftUI

struct LockView: View {
    @ObservedObject var vault: Vault

    @State private var password = ""
    @State private var showPasswordField = false
    @State private var shake = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MountainView()
                .frame(height: 140)
                .frame(maxWidth: 480)
                .padding(.horizontal, DS.space)

            Spacer(minLength: DS.spaceL)

            if showPasswordField {
                HStack(spacing: DS.space / 2) {
                    Image(systemName: "key")
                        .foregroundStyle(DS.ink.opacity(0.5))
                        .frame(width: 20)
                    SecureField("", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, design: .monospaced))
                        .focused($fieldFocused)
                        .onSubmit(tryPassword)
                }
                .padding(DS.space / 1.5)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.corner)
                        .stroke(DS.ink, lineWidth: DS.hairline)
                )
                .modifier(ShakeEffect(shakes: shake ? 2 : 0))
                .animation(.default, value: shake)
                .frame(maxWidth: 360)
                .padding(.horizontal, DS.spaceL)
                .onAppear { fieldFocused = true }
            } else {
                // Повторный вызов Face ID — тап по иконке
                Button(action: tryBiometrics) {
                    Image(systemName: "faceid")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(DS.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock with Face ID")
            }

            Spacer(minLength: DS.spaceL)

            if showPasswordField {
                Button(action: tryPassword) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.paper)
                        .frame(width: DS.controlSize, height: DS.controlSize)
                        .background(Circle().fill(DS.ink))
                }
                .buttonStyle(.plain)
                .disabled(password.isEmpty)
                .opacity(password.isEmpty ? 0.15 : 1)
                .padding(.bottom, DS.spaceXL / 2)
                .accessibilityLabel("Unlock")
            } else {
                Spacer().frame(height: DS.spaceXL / 2 + DS.controlSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.paper)
        .task { tryBiometrics() }
    }

    private func tryBiometrics() {
        Task {
            await vault.unlockWithBiometrics()
            if vault.state != .unlocked {
                withAnimation { showPasswordField = true }
            }
        }
    }

    private func tryPassword() {
        guard !password.isEmpty else { return }
        if !vault.unlockWithPassword(password) {
            password = ""
            shake.toggle()
        }
    }
}
