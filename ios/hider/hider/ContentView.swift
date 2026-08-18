//
//  ContentView.swift
//  hider
//

import SwiftUI

struct ContentView: View {
    @AppStorage("setupComplete") private var setupComplete = false

    var body: some View {
        if setupComplete {
            // Основной экран — следующий этап
            MountainView()
                .padding(DS.spaceXL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.paper)
        } else {
            OnboardingView { password in
                // TODO: вывести ключ из пароля и сохранить в Keychain (этап криптографии)
                _ = password
                setupComplete = true
            }
        }
    }
}

#Preview {
    ContentView()
}
