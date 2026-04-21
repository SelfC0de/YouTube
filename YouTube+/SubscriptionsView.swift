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
                    Button {
                        showAuthSheet = true
                    } label: {
                        Image(systemName: auth.isLoggedIn ? "person.circle.fill" : "person.circle")
                            .foregroundColor(auth.isLoggedIn ? Theme.accent : Theme.text2)
                    }
                }
            }
            .sheet(isPresented: $showAuthSheet) { ImportSheet() }
        }
        .task { if !subscriptions.isEmpty { await loadFeed() } }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.square.stack")
                .font(.system(size: 52))
                .foregroundColor(Theme.text3)
            Text("Нет подписок")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.text2)
            Text("Войдите через Invidious или\nимпортируйте из Google Takeout")
                .font(.system(size: 14))
                .foregroundColor(Theme.text3)
                .multilineTextAlignment(.center)
            Button {
                showAuthSheet = true
            } label: {
                Label("Войти / Импортировать", systemImage: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
        }
        .padding()
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
                        Text(sub.channelName)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.text2)
                            .lineLimit(1)
                            .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Последние видео")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.text2)
                .padding(.horizontal, 16)

            if isLoading {
                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding()
            } else {
                ForEach(feedVideos) { video in
                    NavigationLink(destination: PlayerView(video: video)) {
                        VideoCardView(video: video, compact: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func loadFeed() async {
        isLoading = true
        var videos: [InvidiousVideo] = []
        for sub in subscriptions.prefix(5) {
            let vids = (try? await InvidiousAPI.shared.channelVideos(channelId: sub.channelId)) ?? []
            videos.append(contentsOf: vids.prefix(3))
        }
        feedVideos = videos.sorted { $0.published > $1.published }
        isLoading = false
    }
}

// MARK: - Auth/Import Sheet
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var auth = AuthManager.shared
    @State private var showFilePicker = false
    @State private var importResult: String?
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("Invidious").tag(0)
                        Text("Google CSV").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(16)

                    if tab == 0 { invidiousLogin } else { csvImport }
                    Spacer()
                }
            }
            .navigationTitle(tab == 0 ? "Войти" : "Импорт подписок")
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

    private var invidiousLogin: some View {
        VStack(spacing: 16) {
            if auth.isLoggedIn {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.green)
                    Text("Вы вошли как")
                        .foregroundColor(Theme.text3)
                        .font(.system(size: 13))
                    Text(auth.username)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                    Button {
                        auth.logout()
                    } label: {
                        Text("Выйти")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.bg2).foregroundColor(Theme.accent)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            } else {
                VStack(spacing: 12) {
                    TextField("Имя пользователя", text: $username)
                        .textFieldStyle(YPTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Пароль", text: $password)
                        .textFieldStyle(YPTextFieldStyle())

                    if let err = loginError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        isLoggingIn = true
                        loginError = nil
                        Task {
                            do { try await auth.login(username: username, password: password) }
                            catch { loginError = error.localizedDescription }
                            isLoggingIn = false
                        }
                    } label: {
                        Group {
                            if isLoggingIn {
                                ProgressView().tint(.white)
                            } else {
                                Text("Войти").font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(username.isEmpty || password.isEmpty ? Theme.bg3 : Theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(username.isEmpty || password.isEmpty || isLoggingIn)

                    Text("Аккаунт создаётся на публичном Invidious инстансе. Google аккаунт не нужен.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var csvImport: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach([
                    "1. Откройте takeout.google.com",
                    "2. Выберите только YouTube",
                    "3. Скачайте архив",
                    "4. Найдите subscriptions.csv",
                    "5. Загрузите файл ниже"
                ], id: \.self) { step in
                    Text(step).font(.system(size: 13)).foregroundColor(Theme.text3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.bg2)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))

            if let result = importResult {
                Text(result)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.green)
            }

            Button { showFilePicker = true } label: {
                Label("Выбрать CSV файл", systemImage: "doc.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.accent).foregroundColor(.white)
                    .cornerRadius(14)
            }
        }
        .padding(.horizontal, 20)
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
            .background(Theme.bg2)
            .foregroundColor(Theme.text)
            .font(.system(size: 15))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
