//
//  OnboardingView.swift
//  hider
//
//  Первый запуск: пароль → подтверждение → Face ID.
//  Один инпут, кнопка-стрелка, минимум слов.
//

import SwiftUI
import LocalAuthentication
import os

private let log = Logger(subsystem: "com.webaweba.hider", category: "onboarding")

struct OnboardingView: View {
    enum Step { case password, confirm, biometrics }

    var onComplete: (String) -> Void

    @State private var step: Step = .password
    @State private var input = ""
    @State private var firstPassword = ""
    @State private var shake = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 700
            if wide {
                HStack(spacing: 0) {
                    form(showMountains: false)
                        .frame(width: geo.size.width * 0.45)
                    MountainView()
                        .padding(DS.spaceL)
                }
            } else {
                form(showMountains: true)
            }
        }
        .background(DS.paper)
    }

    private func form(showMountains: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: DS.spaceXL)

            Text("hider")
                .font(.system(size: 40, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.ink)

            Text("hide it in plain sight")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(DS.ink.opacity(0.5))
                .padding(.top, DS.space / 2)

            if showMountains {
                MountainView()
                    .frame(height: 140)
                    .padding(.horizontal, DS.space)
                    .padding(.top, DS.spaceL)
            }

            Spacer(minLength: DS.spaceL)

            passwordBlock
                .padding(.horizontal, DS.spaceL)

            Spacer(minLength: DS.spaceL)

            arrowButton
                .padding(.bottom, DS.spaceXL / 2)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var passwordBlock: some View {
        VStack(spacing: DS.space / 2) {
            switch step {
            case .password, .confirm:
                HStack(spacing: DS.space / 2) {
                    Image(systemName: step == .confirm ? "arrow.counterclockwise" : "key")
                        .foregroundStyle(DS.ink.opacity(0.5))
                        .frame(width: 20)
                    SecureField("", text: $input)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, design: .monospaced))
                        .focused($fieldFocused)
                        .onSubmit(advance)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                }
                .padding(DS.space / 1.5)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.corner)
                        .stroke(DS.ink, lineWidth: DS.hairline)
                )
                .modifier(ShakeEffect(shakes: shake ? 2 : 0))
                .animation(.default, value: shake)

                // Сила пароля — линия вместо слов
                GeometryReader { g in
                    Capsule()
                        .fill(DS.ink)
                        .frame(width: g.size.width * strength(of: input),
                               height: strength(of: input) > 0.6 ? 3 : 1.5)
                        .animation(.easeOut(duration: 0.25), value: input)
                }
                .frame(height: 3)
                .padding(.horizontal, 4)

                if step == .password {
                    // Единственное предупреждение, которое обязано быть словами
                    Text("cannot be recovered")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DS.ink.opacity(0.4))
                        .padding(.top, DS.space / 2)
                }

            case .biometrics:
                Image(systemName: "faceid")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(DS.ink)
                    .transition(.opacity)
            }
        }
        .onAppear { fieldFocused = true }
    }

    private var arrowButton: some View {
        Button(action: advance) {
            Image(systemName: "arrow.right")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DS.paper)
                .frame(width: DS.controlSize, height: DS.controlSize)
                .background(Circle().fill(DS.ink))
        }
        .buttonStyle(.plain)
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.15)
        .animation(.easeOut(duration: 0.2), value: canAdvance)
        .accessibilityLabel(step == .biometrics ? "Enable Face ID" : "Continue")
    }

    private var canAdvance: Bool {
        step == .biometrics || strength(of: input) >= 0.4
    }

    private func advance() {
        switch step {
        case .password:
            guard canAdvance else { return }
            firstPassword = input
            input = ""
            withAnimation { step = .confirm }
        case .confirm:
            if input == firstPassword {
                withAnimation { step = .biometrics }
            } else {
                log.warning("password confirmation mismatch")
                input = ""
                shake.toggle()
            }
        case .biometrics:
            requestBiometrics()
        }
    }

    private func requestBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            log.warning("biometrics unavailable: \(error?.localizedDescription ?? "unknown")")
            onComplete(firstPassword)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Unlock hider") { success, evalError in
            if let evalError { log.warning("biometrics failed: \(evalError.localizedDescription)") }
            DispatchQueue.main.async {
                // Пропуск Face ID не блокирует настройку — пароль уже есть
                _ = success
                onComplete(firstPassword)
            }
        }
    }

    /// 0...1: длина + разнообразие символов
    private func strength(of password: String) -> Double {
        guard !password.isEmpty else { return 0 }
        let classes: [(Character) -> Bool] = [
            { $0.isLowercase }, { $0.isUppercase }, { $0.isNumber },
            { !$0.isLetter && !$0.isNumber },
        ]
        let variety = classes.filter { c in password.contains(where: c) }.count
        let lengthScore = min(Double(password.count) / 12.0, 1.0)
        return min(lengthScore * 0.7 + Double(variety) / 4.0 * 0.3, 1.0)
    }
}

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: 8 * sin(shakes * .pi * 4), y: 0))
    }
}

#Preview {
    OnboardingView { _ in }
}
