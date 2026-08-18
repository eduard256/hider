//
//  hiderApp.swift
//  hider
//

import SwiftUI

@main
struct hiderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .minWindowSize()
        }
        #if os(macOS) || os(iOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}

// Минимум 900x470 для резайзабельных окон (Mac, iPad); iPhone не трогаем
private extension View {
    @ViewBuilder
    func minWindowSize() -> some View {
        #if os(macOS)
        frame(minWidth: 900, minHeight: 470)
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            frame(minWidth: 900, minHeight: 470)
        } else {
            self
        }
        #endif
    }
}
