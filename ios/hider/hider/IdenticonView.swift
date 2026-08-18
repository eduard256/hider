//
//  IdenticonView.swift
//  hider
//
//  Детерминированный ч/б идентикон-гора из хеша публичного ключа.
//  Один и тот же ключ — один и тот же силуэт на обоих устройствах.
//

import SwiftUI
import CryptoKit

struct IdenticonView: View {
    let seed: Data

    private var ridges: [(peaks: [CGPoint], opacity: Double, width: CGFloat)] {
        let hash = Array(SHA256.hash(data: seed))
        let opacities: [Double] = [0.3, 0.55, 1.0]
        var result: [(peaks: [CGPoint], opacity: Double, width: CGFloat)] = []
        for ridge in 0..<3 {
            let base = ridge * 10
            var peaks: [CGPoint] = []
            let count = 4
            for i in 0...count {
                let x = CGFloat(i) / CGFloat(count)
                // Высота вершины из байта хеша: 0.15...0.9
                let byte = hash[(base + i) % hash.count]
                let baseline = 0.35 + CGFloat(ridge) * 0.18
                let amp = CGFloat(byte) / 255 * 0.45
                let y = max(0.1, min(0.95, baseline + 0.25 - amp))
                peaks.append(CGPoint(x: x, y: y))
            }
            let thick = hash[(base + 7) % hash.count] % 2 == 0
            result.append((peaks, opacities[ridge],
                           thick ? DS.stroke : DS.hairline))
        }
        return result
    }

    var body: some View {
        ZStack {
            ForEach(Array(ridges.enumerated()), id: \.offset) { _, ridge in
                RidgeShape(peaks: ridge.peaks)
                    .stroke(DS.ink.opacity(ridge.opacity),
                            style: StrokeStyle(lineWidth: ridge.width,
                                               lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach(["alpha", "beta", "gamma"], id: \.self) { s in
            IdenticonView(seed: Data(s.utf8))
                .frame(width: 44, height: 44)
        }
    }
    .padding()
}
