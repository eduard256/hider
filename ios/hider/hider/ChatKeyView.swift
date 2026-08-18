//
//  ChatKeyView.swift
//  hider
//
//  Страница ключа чата: QR + текстовый ключ (копируется) + done.
//  Открывается после создания чата и в любой момент из списка.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ChatKeyView: View {
    let chat: Chat
    var onDone: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: DS.spaceL) {
            Spacer()

            IdenticonView(seed: chat.keyID)
                .frame(width: 120, height: 72)

            // QR всегда чёрным по белому — иначе не сканируется
            Group {
                if let qr = Self.qrImage(for: "hidr1:\(chat.shortKey)") {
                    Image(decorative: qr, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "xmark")
                }
            }
            .frame(width: 220, height: 220)
            .padding(DS.space / 2)
            .background(RoundedRectangle(cornerRadius: DS.corner).fill(.white))
            .overlay(
                RoundedRectangle(cornerRadius: DS.corner)
                    .stroke(DS.ink.opacity(0.15), lineWidth: DS.hairline)
            )

            // Ключ — тап копирует
            Button(action: copy) {
                HStack(spacing: DS.space / 2) {
                    Text(chat.formattedKey)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(DS.ink)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(DS.ink.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)

            Text("scan or type this key on another device")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DS.ink.opacity(0.4))

            Spacer()

            Button(action: onDone) {
                Text("done")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(DS.paper)
                    .frame(maxWidth: 300)
                    .frame(height: DS.controlSize)
                    .background(Capsule().fill(DS.ink))
            }
            .buttonStyle(.plain)
            .padding(.bottom, DS.spaceXL / 2)
        }
        .padding(.horizontal, DS.spaceL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.paper)
    }

    private func copy() {
        #if os(iOS)
        UIPasteboard.general.string = chat.formattedKey
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(chat.formattedKey, forType: .string)
        #endif
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    private static func qrImage(for string: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
