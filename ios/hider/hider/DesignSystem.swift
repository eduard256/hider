//
//  DesignSystem.swift
//  hider
//
//  Монохром, воздух, вектор. Никаких растровых ассетов.
//

import SwiftUI

enum DS {
    // Отступы — крупный шаг, много воздуха
    static let space: CGFloat = 24
    static let spaceL: CGFloat = 48
    static let spaceXL: CGFloat = 96

    // Штрихи
    static let hairline: CGFloat = 1
    static let stroke: CGFloat = 1.5

    // Единственные два цвета. В тёмной теме инвертируются системой.
    static let ink = Color.primary
    static let paper = Color(light: .white, dark: .black)

    static let corner: CGFloat = 16
    static let controlSize: CGFloat = 64
}

struct ShakeEffect: GeometryEffect {
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

extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}
