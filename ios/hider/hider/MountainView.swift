//
//  MountainView.swift
//  hider
//
//  Line-art горный хребет: три ломаные линии разной "дальности".
//  Чистый вектор, штрих 1–1.5pt.
//

import SwiftUI

struct RidgeShape: Shape {
    /// Нормированные вершины (x: 0...1, y: 0...1, где 1 — низ)
    let peaks: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = peaks.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width,
                              y: rect.minY + first.y * rect.height))
        for p in peaks.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + p.x * rect.width,
                                     y: rect.minY + p.y * rect.height))
        }
        return path
    }
}

struct MountainView: View {
    var animated = true
    @State private var drawn = false

    // Дальний, средний, ближний хребты
    private static let ridges: [[CGPoint]] = [
        [.init(x: 0, y: 0.55), .init(x: 0.18, y: 0.32), .init(x: 0.33, y: 0.48),
         .init(x: 0.5, y: 0.2), .init(x: 0.66, y: 0.42), .init(x: 0.82, y: 0.28),
         .init(x: 1, y: 0.5)],
        [.init(x: 0, y: 0.75), .init(x: 0.22, y: 0.5), .init(x: 0.4, y: 0.68),
         .init(x: 0.6, y: 0.44), .init(x: 0.78, y: 0.62), .init(x: 1, y: 0.52)],
        [.init(x: 0, y: 0.9), .init(x: 0.3, y: 0.66), .init(x: 0.55, y: 0.88),
         .init(x: 0.75, y: 0.7), .init(x: 1, y: 0.86)],
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.ridges.enumerated()), id: \.offset) { index, peaks in
                RidgeShape(peaks: peaks)
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(DS.ink.opacity(index == 2 ? 1 : index == 1 ? 0.55 : 0.3),
                            style: StrokeStyle(lineWidth: index == 2 ? DS.stroke : DS.hairline,
                                               lineCap: .round, lineJoin: .round))
                    .animation(.easeOut(duration: 1.2).delay(Double(index) * 0.2),
                               value: drawn)
            }
        }
        .onAppear { drawn = !animated ? true : drawn }
        .task { if animated { drawn = true } }
        .accessibilityHidden(true)
    }
}

#Preview {
    MountainView()
        .frame(height: 200)
        .padding()
}
