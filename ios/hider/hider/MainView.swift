//
//  MainView.swift
//  hider
//
//  Главный экран: список контактов + нижняя панель.
//  Панель в двух режимах: поиск/+  ↔  имя нового контакта/крестик-галочка.
//

import SwiftUI

struct Contact: Identifiable, Equatable {
    let id = UUID()
    let name: String
    // Пока идентикон из имени; позже — из публичного ключа
    var seed: Data { Data(name.utf8) }
}

struct MainView: View {
    @State private var contacts: [Contact] = []
    @State private var qrContact: Contact?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if contacts.isEmpty {
                    emptyState
                } else {
                    contactList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomBar { name in
                let contact = Contact(name: name)
                withAnimation { contacts.append(contact) }
                qrContact = contact
            }
            .padding(.horizontal, DS.space)
            .padding(.bottom, DS.space)
        }
        .background(DS.paper)
        .overlay {
            if let contact = qrContact {
                qrOverlay(for: contact)
            }
        }
    }

    // MARK: - Список

    private var contactList: some View {
        ScrollView {
            VStack(spacing: DS.space / 2) {
                ForEach(contacts) { contact in
                    HStack(spacing: DS.space / 2) {
                        IdenticonView(seed: contact.seed)
                            .frame(width: 44, height: 32)
                        Text(contact.name)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(DS.ink)
                        Spacer()
                        Button { qrContact = contact } label: {
                            Image(systemName: "qrcode")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(DS.ink.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show QR")
                    }
                    .padding(DS.space / 1.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.corner)
                            .stroke(DS.ink.opacity(0.25), lineWidth: DS.hairline)
                    )
                }
            }
            .padding(.horizontal, DS.space)
            .padding(.top, DS.space)
            .padding(.bottom, DS.controlSize + DS.spaceL)
        }
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

    // MARK: - QR контакта (пока плейсхолдер)

    private func qrOverlay(for contact: Contact) -> some View {
        VStack(spacing: DS.spaceL) {
            IdenticonView(seed: contact.seed)
                .frame(width: 120, height: 72)

            RoundedRectangle(cornerRadius: DS.corner)
                .stroke(DS.ink, lineWidth: DS.stroke)
                .frame(width: 240, height: 240)
                .overlay(
                    // Плейсхолдер QR — заменится на настоящий код
                    Image(systemName: "qrcode")
                        .font(.system(size: 160, weight: .ultraLight))
                        .foregroundStyle(DS.ink.opacity(0.2))
                )

            Text(contact.name)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(DS.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.paper)
        .onTapGesture { withAnimation { qrContact = nil } }
        .transition(.opacity)
    }
}

// MARK: - Нижняя панель

struct BottomBar: View {
    var onCreate: (String) -> Void

    @State private var adding = false
    @State private var name = ""
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @FocusState private var nameFocused: Bool
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
            field
                .modifier(GlassOrMaterial(glass: glass, shape: .capsule,
                                          id: "field", namespace: glassNamespace))

            actionButton
                .modifier(GlassOrMaterial(glass: glass, shape: .circle,
                                          id: "action", namespace: glassNamespace))
        }
        .animation(.bouncy(duration: 0.35), value: adding)
        .animation(.bouncy(duration: 0.35), value: name.isEmpty)
        .animation(.easeOut(duration: 0.25), value: nameFocused)
        .animation(.easeOut(duration: 0.25), value: searchFocused)
    }

    // Поле: поиск ↔ имя нового контакта
    private var field: some View {
        HStack(spacing: DS.space / 2) {
            Image(systemName: adding ? "person" : "magnifyingglass")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(DS.ink.opacity(0.45))
                .contentTransition(.symbolEffect(.replace))

            if adding {
                TextField("", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($nameFocused)
                    .onSubmit(create)
            } else {
                TextField("", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($searchFocused)
            }
        }
        .padding(.horizontal, DS.space / 1.5)
        .frame(height: DS.controlSize)
        .frame(maxWidth: .infinity)
        .contentShape(Capsule())
        .onTapGesture { (adding ? $nameFocused : $searchFocused).wrappedValue = true }
    }

    // Кнопка: + ↔ крестик ↔ галочка
    private var actionButton: some View {
        Button(action: tapAction) {
            Image(systemName: adding && !name.isEmpty ? "checkmark" : "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(DS.ink)
                .contentTransition(.symbolEffect(.replace))
                // + поворачивается в крестик
                .rotationEffect(.degrees(adding && name.isEmpty ? 45 : 0))
                .frame(width: DS.controlSize, height: DS.controlSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(adding ? (name.isEmpty ? "Cancel" : "Create contact") : "Add contact")
    }

    private func tapAction() {
        if !adding {
            withAnimation(.bouncy(duration: 0.35)) {
                adding = true
                name = ""
            }
            nameFocused = true
        } else if name.isEmpty {
            dismissKeyboardSmoothly()
            withAnimation(.bouncy(duration: 0.35)) { adding = false }
        } else {
            create()
        }
    }

    private func create() {
        guard !name.isEmpty else { return }
        dismissKeyboardSmoothly()
        onCreate(name)
        name = ""
        withAnimation(.bouncy(duration: 0.35)) { adding = false }
    }

    /// Снимаем фокус внутри анимации — панель плавно опускается вместе с клавиатурой
    private func dismissKeyboardSmoothly() {
        withAnimation(.easeOut(duration: 0.25)) {
            nameFocused = false
            searchFocused = false
        }
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
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
