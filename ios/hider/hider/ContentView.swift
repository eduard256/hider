//
//  ContentView.swift
//  hider
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vault = Vault()

    var body: some View {
        switch vault.state {
        case .needsSetup:
            OnboardingView { password in
                do {
                    try vault.create(password: password)
                } catch {
                    // Создание хранилища упало — это фатально для настройки
                    assertionFailure("vault creation failed: \(error)")
                }
            }
        case .locked:
            LockView(vault: vault)
        case .unlocked:
            MainView(vault: vault)
        }
    }
}

#Preview {
    ContentView()
}
