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
    @State private var adding = false

    private enum AddMode { case qr, key }
    #if os(macOS)
    @State private var addMode: AddMode = .key
    private static let defaultAddMode: AddMode = .key
    #else
    @State private var addMode: AddMode = .qr
    private static let defaultAddMode: AddMode = .qr
    #endif

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if adding {
                    addingState
                        .transition(.opacity.combined(with: .offset(y: 24)))
                } else if contacts.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    contactList
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.bouncy(duration: 0.35), value: adding)
            .onChange(of: adding) { _, newValue in
                if !newValue { addMode = Self.defaultAddMode }
            }

            BottomBar(adding: $adding) { name in
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

    // Страница добавления: сверху сканер QR (на Маке — ключ, вебка по кнопке),
    // снизу стрелка на поле имени.
    private var addingState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: DS.spaceL)

            Group {
                if addMode == .qr {
                    scannerBlock
                        .transition(.opacity)
                } else {
                    keyBlock
                        .transition(.opacity)
                }
            }
            .animation(.bouncy(duration: 0.35), value: addMode == .qr)

            // Подпись — переключатель между QR и ключом
            Button {
                addMode = addMode == .qr ? .key : .qr
            } label: {
                Text(addMode == .qr ? "add via key" : "add via qr")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(DS.ink.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(.top, DS.space)

            Spacer(minLength: DS.space)

            HStack(spacing: DS.space / 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(DS.ink.opacity(0.35))
                    .padding(.leading, DS.space)
                Text("create new chat")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(DS.ink.opacity(0.8))
                Spacer()
            }
            .padding(.bottom, DS.spaceL + DS.controlSize)
        }
    }

    // Камера: квадрат со скруглением
    private var scannerBlock: some View {
        VStack(spacing: DS.space) {
            Text("add someone else's chat")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DS.ink.opacity(0.4))

            QRScannerView { code in
                // TODO: обмен ключами — этап криптографии
                _ = code
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 300)
            .clipShape(RoundedRectangle(cornerRadius: DS.corner))
            .padding(.horizontal, DS.spaceL)
        }
    }

    // Ключ: 4 поля по 4 символа, XXXX-XXXX-XXXX-XXXX
    private var keyBlock: some View {
        VStack(spacing: DS.space) {
            Text("add someone else's chat")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DS.ink.opacity(0.4))

            KeyCodeInput { key in
                // TODO: подключение по ключу — этап криптографии
                _ = key
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, DS.spaceL)

            Text("type the key from the other device")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DS.ink.opacity(0.4))
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

// Ввод ключа: одно логическое поле, отрисованное как 4 сегмента по 4 символа.
// Скрытый TextField держит всю строку — вставка, очистка и backspace
// работают как в обычном поле.
struct KeyCodeInput: View {
    var onComplete: (String) -> Void

    @State private var key = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            // Невидимое настоящее поле — принимает весь ввод
            TextField("", text: $key)
                .textFieldStyle(.plain)
                .focused($focused)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                #endif
                .opacity(0.02)

            // Визуальные сегменты
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    Text(segment(index))
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(DS.ink)
                        .frame(height: DS.controlSize / 1.5)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.corner)
                                .stroke(DS.ink.opacity(activeSegment == index ? 1 : 0.4),
                                        lineWidth: DS.stroke)
                        )
                        .animation(.easeOut(duration: 0.15), value: activeSegment)

                    if index < 3 {
                        Rectangle()
                            .fill(DS.ink.opacity(0.4))
                            .frame(width: DS.space / 2, height: DS.stroke)
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        // Автофокус при появлении (переключение с qr на ключ)
        .onAppear { focused = true }
        .onChange(of: key) { _, newValue in
            let clean = String(newValue.uppercased()
                .filter(\.isAlphanumeric)
                .prefix(16))
            if clean != key { key = clean }
            if clean.count == 16 {
                focused = false
                onComplete(clean)
            }
        }
    }

    private var activeSegment: Int { min(key.count / 4, 3) }

    private func segment(_ index: Int) -> String {
        let start = index * 4
        guard key.count > start else { return "" }
        let chars = Array(key)
        return String(chars[start..<min(start + 4, chars.count)])
    }
}

private extension Character {
    var isAlphanumeric: Bool { isLetter || isNumber }
}

// MARK: - Нижняя панель

struct BottomBar: View {
    @Binding var adding: Bool
    var onCreate: (String) -> Void

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
                TextField("", text: $name,
                          prompt: Text("name the new chat")
                              .font(.system(.body, design: .monospaced))
                              .foregroundStyle(DS.ink.opacity(0.3)))
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
