//
//  MainView.swift
//  hider
//
//  Главный экран: список контактов (пока пусто) + нижняя панель:
//  большой поиск и одна кнопка QR. Только UI — без логики.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomBar()
                .padding(.horizontal, DS.space)
                .padding(.bottom, DS.space)
        }
        .background(DS.paper)
    }

    private var emptyState: some View {
        VStack(spacing: DS.spaceL) {
            Spacer()

            IdenticonView(seed: Data("hider".utf8))
                .frame(width: 160, height: 100)
                .opacity(0.25)

            Text("no one yet")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(DS.ink.opacity(0.35))

            Spacer()

            // Стрелка ведёт к кнопке QR в панели
            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(DS.ink.opacity(0.35))
                    .padding(.trailing, DS.controlSize / 2 + DS.space - 10)
            }
            .padding(.bottom, DS.spaceL + DS.controlSize)
        }
    }
}

// MARK: - Нижняя панель: поиск во всю ширину + кнопка QR

struct BottomBar: View {
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @Namespace private var glassNamespace

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: DS.space / 2) {
                content(glass: true)
            }
        } else {
            content(glass: false)
        }
    }

    @ViewBuilder
    private func content(glass: Bool) -> some View {
        HStack(spacing: DS.space / 2) {
            searchField
                .modifier(GlassOrMaterial(glass: glass, shape: .capsule,
                                          id: "search", namespace: glassNamespace))

            qrButton
                .modifier(GlassOrMaterial(glass: glass, shape: .circle,
                                          id: "qr", namespace: glassNamespace))
        }
    }

    private var searchField: some View {
        HStack(spacing: DS.space / 2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(DS.ink.opacity(0.45))
            TextField("", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .focused($searchFocused)
        }
        .padding(.horizontal, DS.space / 1.5)
        .frame(height: DS.controlSize)
        .frame(maxWidth: .infinity)
        .contentShape(Capsule())
        .onTapGesture { searchFocused = true }
    }

    private var qrButton: some View {
        Button {
            // Действий пока нет — только раскладка UI
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(DS.ink)
                .frame(width: DS.controlSize, height: DS.controlSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add contact")
    }
}

// MARK: - Liquid Glass с фолбэком для старых ОС

private struct GlassOrMaterial: ViewModifier {
    enum BarShape { case capsule, circle }

    let glass: Bool
    let shape: BarShape
    let id: String
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *), glass {
            switch shape {
            case .capsule:
                content
                    .glassEffect(reduceTransparency ? .identity : .regular.interactive(),
                                 in: .capsule)
                    .glassEffectID(id, in: namespace)
            case .circle:
                content
                    .glassEffect(reduceTransparency ? .identity : .regular.interactive(),
                                 in: .circle)
                    .glassEffectID(id, in: namespace)
            }
        } else {
            content
                .background(.ultraThinMaterial,
                            in: AnyShape(shape == .capsule ? AnyShape(Capsule()) : AnyShape(Circle())))
                .overlay(
                    AnyShape(shape == .capsule ? AnyShape(Capsule()) : AnyShape(Circle()))
                        .stroke(DS.ink.opacity(0.1), lineWidth: DS.hairline)
                )
        }
    }
}

#Preview {
    MainView()
}
