import LockedInData
import LockedInDomain
import SwiftUI

struct AuthenticationView: View {
  @AppStorage(AppAccent.preferenceKey) private var accent: AppAccent = .violet
  @Bindable var model: AppModel
  @State private var registering = false
  @State private var username: String
  @State private var password = ""
  @State private var confirmation = ""
  @State private var passwordVisible = false
  @State private var confirmationVisible = false
  @State private var emoji = ""
  @State private var address: String
  @State private var showServer = false
  @State private var working = false
  @State private var message: String?
  init(model: AppModel) {
    self.model = model
    _address = State(initialValue: model.settings.serverAddress)
    _username = State(initialValue: UserDefaults.standard.string(forKey: "trackit.auth.lastUsername:" + model.settings.serverAddress) ?? "")
  }
  private enum Field: Hashable { case username, password, confirmation, server }
  @FocusState private var focusedField: Field?
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var tabs

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.015)
        RadialGradient(colors: [Color.accent.opacity(colorScheme == .dark ? 0.14 : 0.09), .clear],
          center: .init(x: 0.25, y: 0.18), startRadius: 12, endRadius: 650)
          .allowsHitTesting(false)
        ScrollView {
          VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 26) {
              heading
              accountTabs
              VStack(spacing: 12) {
                inputField("Логин", symbol: "person", field: .username) {
                  TextField("Твой логин", text: $username).textContentType(.username).autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .accessibilityLabel("Логин")
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                }
                inputField("Пароль", symbol: "lock", field: .password) {
                  passwordEntry(registering ? "Придумай пароль" : "Введи пароль",
                    text: $password, field: .password, visible: $passwordVisible)
                }
                if registering {
                  inputField("Ещё раз", symbol: "lock.badge.checkmark", field: .confirmation) {
                    passwordEntry("Повтори пароль", text: $confirmation,
                      field: .confirmation, visible: $confirmationVisible)
                  }
                  AvatarSelectionRow(emoji: $emoji, surface: fieldSurface)
                  Text("Логин — 3–32 латинских символа, цифры, _ . −. Пароль — от 8 символов.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 2)
                }
              }.onSubmit { submit() }
              if let message = message ?? model.errorMessage {
                Label(message, systemImage: "exclamationmark.circle")
                  .font(.system(size: 13)).foregroundStyle(.red)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              submitButton
              serverSettings
            }.padding(geometry.size.width < 560 ? 24 : 34)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
              .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Color.primary.opacity(0.07)))
              .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.06), radius: 32, y: 14)
              .disabled(working)
            Label("Задачи, доски и теги — только в твоём аккаунте.", systemImage: "lock.shield")
              .font(.system(size: 12)).foregroundStyle(.secondary)
              .multilineTextAlignment(.center).padding(.horizontal, 12)
          }.frame(maxWidth: 510)
            .padding(.horizontal, geometry.size.width < 560 ? 18 : 36)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .frame(minHeight: geometry.size.height)
        }.scrollIndicators(.hidden)
      }
    }
    .submitOnEnter(enabled: !working) { submit() }
    .onAppear { focusedField = username.isEmpty ? .username : .password }
    #if os(iOS)
    .onReceive(NotificationCenter.default.publisher(for: .keyboardDismissedOutside)) { _ in focusedField = nil }
    #endif
    .onChange(of: registering) { _, _ in
      message = nil; model.errorMessage = nil; password = ""; confirmation = ""
      passwordVisible = false; confirmationVisible = false
      focusedField = .username
    }
  }
  private func passwordEntry(_ placeholder: String, text: Binding<String>, field: Field,
    visible: Binding<Bool>) -> some View {
    HStack(spacing: 10) {
      Group {
        if visible.wrappedValue {
          TextField(placeholder, text: text)
            .focused($focusedField, equals: field)
        } else {
          SecureField(placeholder, text: text)
            .focused($focusedField, equals: field)
        }
      }.textContentType(registering ? .newPassword : .password)
        .autocorrectionDisabled()
        .accessibilityLabel(field == .confirmation ? "Повтори пароль" : "Пароль")
        #if os(iOS)
        .textInputAutocapitalization(.never)
        #endif
      Button {
        visible.wrappedValue.toggle()
        DispatchQueue.main.async { focusedField = field }
      } label: {
        Image(systemName: visible.wrappedValue ? "eye.slash" : "eye")
          .font(.system(size: 16)).foregroundStyle(.secondary)
          .frame(width: 32, height: 28).contentShape(Rectangle())
      }.buttonStyle(.plain)
        .help(visible.wrappedValue ? "Скрыть пароль" : "Показать пароль")
        .accessibilityLabel(visible.wrappedValue ? "Скрыть пароль" : "Показать пароль")
    }
  }
  private var fieldSurface: Color {
    colorScheme == .dark ? .white.opacity(0.045) : .white.opacity(0.7)
  }
  private var heading: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 12) {
        Image(systemName: "scope").font(.system(size: 25, weight: .light)).foregroundStyle(.white)
          .frame(width: 46, height: 46)
          .background(LinearGradient(colors: [Color.accent, accent.brandHighlight],
            startPoint: .bottomLeading, endPoint: .topTrailing), in: RoundedRectangle(cornerRadius: 15))
        Text("TrackIt").font(.system(size: 23, weight: .bold, design: .rounded))
      }
      VStack(alignment: .leading, spacing: 7) {
        Text(registering ? "Твоё пространство." : "С возвращением.")
          .font(.system(size: 31, weight: .semibold, design: .rounded)).tracking(-0.7)
          .fixedSize(horizontal: false, vertical: true)
        Text(registering ? "Начни с аккаунта. Дальше — твои планы." : "Войди, чтобы продолжить свои планы.")
          .font(.system(size: 14)).foregroundStyle(.secondary)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private var accountTabs: some View {
    HStack(spacing: 3) {
      accountTab("Войти", registering: false)
      accountTab("Регистрация", registering: true)
    }.padding(4).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
  }
  private func accountTab(_ title: String, registering value: Bool) -> some View {
    Button {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { registering = value }
    } label: {
      Text(title).font(.system(size: 14, weight: .semibold))
        .foregroundStyle(registering == value ? Color.primary : Color.secondary)
        .frame(maxWidth: .infinity).frame(height: 39)
        .background {
          if registering == value {
            RoundedRectangle(cornerRadius: 11).fill(fieldSurface)
              .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.primary.opacity(0.055)))
              .matchedGeometryEffect(id: "account-tab", in: tabs)
          }
        }.contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityAddTraits(registering == value ? .isSelected : [])
  }
  private func inputField<Content: View>(_ label: String, symbol: String, field: Field,
    @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 14) {
      Image(systemName: symbol).font(.system(size: 18, weight: .regular))
        .foregroundStyle(focusedField == field ? Color.accent : Color.secondary)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        content().font(.system(size: 17)).textFieldStyle(.plain)
      }
    }.padding(.horizontal, 17).padding(.vertical, 12).frame(minHeight: 69)
      .background(fieldSurface, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
        focusedField == field ? Color.accent.opacity(0.75) : Color.primary.opacity(0.075),
        lineWidth: focusedField == field ? 1.5 : 1))
      .contentShape(RoundedRectangle(cornerRadius: 16))
      .keyboardInputArea()
      .simultaneousGesture(TapGesture().onEnded { focusedField = field })
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: focusedField)
  }
  private var submitButton: some View {
    let unavailable = working || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    return Button(action: submit) {
      HStack(spacing: 10) {
        if working { ProgressView().controlSize(.small).tint(.white) }
        Text(registering ? "Создать аккаунт" : "Войти").font(.system(size: 16, weight: .semibold))
      }.frame(maxWidth: .infinity).frame(height: 54)
        .overlay(alignment: .trailing) {
          if !working { Image(systemName: "arrow.right").font(.system(size: 15, weight: .semibold)).padding(.trailing, 20) }
        }
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Color.accent, accent.buttonHighlight],
          startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16))
        .opacity(unavailable ? 0.5 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }.buttonStyle(.plain).disabled(unavailable).keyboardShortcut(.defaultAction)
  }
  private var serverSettings: some View {
    VStack(spacing: 12) {
      Button {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { showServer.toggle() }
      } label: {
        HStack(spacing: 6) {
          Text("Сервер").font(.system(size: 12, weight: .medium))
          Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            .rotationEffect(.degrees(showServer ? 180 : 0))
          Spacer(minLength: 10)
          Text(address).font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
        }.foregroundStyle(.secondary).contentShape(Rectangle())
      }.buttonStyle(.plain)
      if showServer {
        inputField("Адрес сервера", symbol: "network", field: .server) {
          TextField("https://…", text: $address).autocorrectionDisabled()
            .focused($focusedField, equals: .server)
        }.transition(.opacity)
      }
    }
  }
  private func submit() {
    guard !working else { return }
    message = nil
    if registering {
      guard password == confirmation else { message = "Пароли не совпадают."; return }
      guard password.count >= 8, password.utf8.count <= 256 else { message = "Пароль слишком короткий или длинный. Минимум — 8 символов."; return }
      guard emoji.isEmpty || ProfileEmoji.valid(emoji) else { message = "Выбери один эмоджи для аватарки."; return }
    }
    working = true
    Task {
      defer { working = false }
      do {
        try await model.authenticate(username: username.trimmingCharacters(in: .whitespacesAndNewlines),
          password: password, registering: registering, emoji: emoji, address: address.trimmingCharacters(in: .whitespacesAndNewlines))
        password = ""; confirmation = ""
      } catch { message = model.friendly(error) }
    }
  }
}
