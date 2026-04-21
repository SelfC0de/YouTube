import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var context
    @Query private var subscriptions: [LocalSubscription]
    @StateObject private var auth = AuthManager.shared
    @State private var feedVideos: [InvidiousVideo] = []
    @State private var isLoading = false
    @State private var showAuthSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if subscriptions.isEmpty && !auth.isLoggedIn {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !subscriptions.isEmpty { channelsList }
                            Divider().background(Color.white.opacity(0.06)).padding(.vertical, 8)
                            feedSection
                        }
                    }
                }
            }
            .navigationTitle("Подписки")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bg2, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAuthSheet = true } label: {
                        Image(systemName: auth.isLoggedIn ? "person.circle.fill" : "person.circle")
                            .foregroundColor(auth.isLoggedIn ? Theme.accent : Theme.text2)
                    }
                }
            }
            .sheet(isPresented: $showAuthSheet) { AuthSheet() }
        }
        .task { if !subscriptions.isEmpty { await loadFeed() } }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.square.stack").font(.system(size: 52)).foregroundColor(Theme.text3)
            Text("Нет подписок").font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text2)
            Text("Войдите или зарегистрируйтесь\nлибо импортируйте из Google Takeout")
                .font(.system(size: 14)).foregroundColor(Theme.text3).multilineTextAlignment(.center)
            Button { showAuthSheet = true } label: {
                Label("Войти / Зарегистрироваться", systemImage: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.accent).foregroundColor(.white).cornerRadius(14)
            }
        }.padding()
    }

    private var channelsList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(subscriptions) { sub in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 52, height: 52)
                            .overlay(Text(String(sub.channelName.prefix(1))).font(.system(size: 18, weight: .bold)).foregroundColor(.white))
                        Text(sub.channelName).font(.system(size: 10)).foregroundColor(Theme.text2).lineLimit(1).frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Последние видео").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text2).padding(.horizontal, 16)
            if isLoading {
                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding()
            } else {
                ForEach(feedVideos) { video in
                    NavigationLink(destination: PlayerView(video: video)) {
                        VideoCardView(video: video, compact: true)
                    }
                    .buttonStyle(.plain).padding(.horizontal, 16)
                }
            }
        }.padding(.bottom, 20)
    }

    private func loadFeed() async {
        isLoading = true
        var videos: [InvidiousVideo] = []
        for sub in subscriptions.prefix(5) {
            let vids = (try? await InvidiousAPI.shared.channelVideos(channelId: sub.channelId)) ?? []
            videos.append(contentsOf: vids.prefix(3))
        }
        feedVideos = videos.sorted { ($0.published ?? 0) > ($1.published ?? 0) }
        isLoading = false
    }
}

// MARK: - AuthSheet
struct AuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var auth = AuthManager.shared
    @State private var tab = 0  // 0=login, 1=register, 2=csv

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("Вход").tag(0)
                        Text("Регистрация").tag(1)
                        Text("CSV").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(16)

                    ScrollView {
                        switch tab {
                        case 0: LoginForm()
                        case 1: RegisterForm()
                        default: CSVImportForm()
                        }
                    }
                }
            }
            .navigationTitle(tab == 0 ? "Войти" : tab == 1 ? "Регистрация" : "Импорт подписок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg2, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }.foregroundColor(Theme.accent)
                }
            }
        }
        .presentationBackground(Theme.bg)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - LoginForm
struct LoginForm: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var auth = AuthManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            if auth.isLoggedIn {
                loggedInState
            } else {
                loginFields
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var loggedInState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundColor(Theme.green)
            Text("Вы вошли как").font(.system(size: 13)).foregroundColor(Theme.text3)
            Text(auth.username).font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
            Button {
                auth.logout()
            } label: {
                Text("Выйти").font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.bg2).foregroundColor(Theme.accent).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.top, 20)
    }

    private var loginFields: some View {
        VStack(spacing: 12) {
            TextField("Имя пользователя", text: $username)
                .textFieldStyle(YPTextFieldStyle()).autocorrectionDisabled().textInputAutocapitalization(.never)
            SecureField("Пароль", text: $password)
                .textFieldStyle(YPTextFieldStyle())

            if let err = error {
                Text(err).font(.system(size: 12)).foregroundColor(Theme.accent).frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                isLoading = true; error = nil
                Task {
                    do { try await auth.login(username: username, password: password) }
                    catch { self.error = error.localizedDescription }
                    isLoading = false
                }
            } label: {
                Group {
                    if isLoading { ProgressView().tint(.white) }
                    else { Text("Войти").font(.system(size: 15, weight: .semibold)) }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(username.isEmpty || password.isEmpty ? Theme.bg3 : Theme.accent)
                .foregroundColor(.white).cornerRadius(14)
            }
            .disabled(username.isEmpty || password.isEmpty || isLoading)

            Text("Аккаунт Invidious — не Google.")
                .font(.system(size: 11)).foregroundColor(Theme.text3).multilineTextAlignment(.center)
        }
    }
}

// MARK: - RegisterForm
struct RegisterForm: View {
    @StateObject private var auth = AuthManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var success = false

    private var passwordsMatch: Bool { password == passwordConfirm }
    private var canSubmit: Bool { !username.isEmpty && password.count >= 6 && passwordsMatch && !isLoading }

    var body: some View {
        VStack(spacing: 14) {
            if auth.isLoggedIn || success {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundColor(Theme.green)
                    Text("Аккаунт создан!").font(.system(size: 20, weight: .bold)).foregroundColor(Theme.text)
                    Text("Вы вошли как \(auth.username)").font(.system(size: 14)).foregroundColor(Theme.text2)
                }
                .padding(.top, 20)
            } else {
                TextField("Имя пользователя", text: $username)
                    .textFieldStyle(YPTextFieldStyle()).autocorrectionDisabled().textInputAutocapitalization(.never)

                SecureField("Пароль (мин. 6 символов)", text: $password)
                    .textFieldStyle(YPTextFieldStyle())

                SecureField("Подтвердите пароль", text: $passwordConfirm)
                    .textFieldStyle(YPTextFieldStyle())
                    .overlay(alignment: .trailing) {
                        if !passwordConfirm.isEmpty {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(passwordsMatch ? Theme.green : Theme.accent)
                                .padding(.trailing, 14)
                        }
                    }

                if !passwordConfirm.isEmpty && !passwordsMatch {
                    Text("Пароли не совпадают").font(.system(size: 12)).foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let err = error {
                    Text(err).font(.system(size: 12)).foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    isLoading = true; error = nil
                    Task {
                        do {
                            try await auth.register(username: username, password: password)
                            success = true
                        } catch { self.error = error.localizedDescription }
                        isLoading = false
                    }
                } label: {
                    Group {
                        if isLoading { ProgressView().tint(.white) }
                        else { Text("Зарегистрироваться").font(.system(size: 15, weight: .semibold)) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(canSubmit ? Theme.accent : Theme.bg3)
                    .foregroundColor(.white).cornerRadius(14)
                }
                .disabled(!canSubmit)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Аккаунт создаётся на Invidious инстансе.")
                        .font(.system(size: 11)).foregroundColor(Theme.text3)
                    Text("Google аккаунт не требуется.")
                        .font(.system(size: 11)).foregroundColor(Theme.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - CSVImportForm
struct CSVImportForm: View {
    @Environment(\.modelContext) private var context
    @StateObject private var auth = AuthManager.shared
    @State private var showFilePicker = false
    @State private var importResult: String?

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(["1. Откройте takeout.google.com",
                         "2. Выберите только YouTube",
                         "3. Скачайте архив",
                         "4. Найдите subscriptions.csv",
                         "5. Загрузите файл ниже"], id: \.self) { step in
                    Text(step).font(.system(size: 13)).foregroundColor(Theme.text3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(Theme.bg2).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))

            if let result = importResult {
                Text(result).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.green)
            }

            Button { showFilePicker = true } label: {
                Label("Выбрать CSV файл", systemImage: "doc.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.accent).foregroundColor(.white).cornerRadius(14)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    let count = (try? auth.importSubscriptionsFromCSV(data: data, context: context)) ?? 0
                    importResult = "Импортировано \(count) подписок"
                }
            case .failure:
                importResult = "Ошибка чтения файла"
            }
        }
    }
}

struct YPTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Theme.bg2).foregroundColor(Theme.text).font(.system(size: 15))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
