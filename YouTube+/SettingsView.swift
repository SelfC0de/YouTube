import SwiftUI

struct SettingsView: View {
    @StateObject private var api = InvidiousAPI.shared
    @State private var showHistory = false
    @State private var sponsorBlockEnabled = UserDefaults.standard.bool(forKey: "sponsorBlockEnabled")
    @State private var returnDislikeEnabled: Bool = {
        UserDefaults.standard.object(forKey: "returnDislikeEnabled") == nil
            ? true : UserDefaults.standard.bool(forKey: "returnDislikeEnabled")
    }()

    // Свой сервер
    @State private var ownServerEnabled = UserDefaults.standard.bool(forKey: "ownServerEnabled")
    @State private var ownServerURL = UserDefaults.standard.string(forKey: "ownServerURL") ?? ""
    @State private var ownServerUser = UserDefaults.standard.string(forKey: "ownServerUser") ?? "admin"
    @State private var ownServerPass = UserDefaults.standard.string(forKey: "ownServerPass") ?? ""
    @State private var testingServer = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    ownServerSection
                    statusSection
                    featuresSection
                    historySection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bg2, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showHistory) { HistoryView() }
    }

    // MARK: - Own Server
    private var ownServerSection: some View {
        Section {
            Toggle(isOn: $ownServerEnabled) {
                Label("Свой сервер", systemImage: "server.rack")
                    .foregroundColor(Theme.text).font(.system(size: 13))
            }
            .tint(Theme.accent)
            .onChange(of: ownServerEnabled) { _, v in
                UserDefaults.standard.set(v, forKey: "ownServerEnabled")
                Task { await api.resetAndFind() }
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))

            if ownServerEnabled {
                TextField("URL (https://...)", text: $ownServerURL)
                    .foregroundColor(Theme.text).font(.system(size: 13))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .onChange(of: ownServerURL) { _, v in
                        UserDefaults.standard.set(v, forKey: "ownServerURL")
                    }
                    .listRowBackground(Theme.bg2)
                    .listRowSeparatorTint(Color.white.opacity(0.06))

                TextField("Логин", text: $ownServerUser)
                    .foregroundColor(Theme.text).font(.system(size: 13))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .onChange(of: ownServerUser) { _, v in
                        UserDefaults.standard.set(v, forKey: "ownServerUser")
                    }
                    .listRowBackground(Theme.bg2)
                    .listRowSeparatorTint(Color.white.opacity(0.06))

                SecureField("Пароль", text: $ownServerPass)
                    .foregroundColor(Theme.text).font(.system(size: 13))
                    .onChange(of: ownServerPass) { _, v in
                        UserDefaults.standard.set(v, forKey: "ownServerPass")
                    }
                    .listRowBackground(Theme.bg2)
                    .listRowSeparatorTint(Color.white.opacity(0.06))

                Button {
                    testingServer = true
                    testResult = nil
                    Task {
                        await api.resetAndFind()
                        if api.currentInstance == ownServerURL || api.currentInstance.contains("свой") {
                            testResult = "✓ Подключено"
                        } else {
                            testResult = "✗ Не удалось подключиться"
                        }
                        testingServer = false
                    }
                } label: {
                    HStack {
                        Label("Проверить подключение", systemImage: "network")
                            .foregroundColor(Theme.accent).font(.system(size: 13))
                        Spacer()
                        if testingServer {
                            ProgressView().tint(Theme.accent).scaleEffect(0.8)
                        } else if let r = testResult {
                            Text(r).font(.system(size: 12))
                                .foregroundColor(r.hasPrefix("✓") ? Theme.green : Theme.accent)
                        }
                    }
                }
                .listRowBackground(Theme.bg2)
                .listRowSeparatorTint(Color.white.opacity(0.06))
            }
        } header: {
            Text("Свой Yattee Server")
                .foregroundColor(Theme.text3).font(.system(size: 11))
        } footer: {
            if ownServerEnabled {
                Text("Свой сервер имеет приоритет над публичными инстансами")
                    .foregroundColor(Theme.text3).font(.system(size: 10))
            }
        }
    }

    // MARK: - Status
    private var statusSection: some View {
        Section {
            HStack(spacing: 10) {
                Circle()
                    .fill(api.currentInstance.isEmpty ? Theme.text3 : Theme.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: api.currentInstance.isEmpty ? .clear : Theme.green, radius: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(api.currentInstance.isEmpty ? "Поиск..." : "Подключено")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(Theme.text)
                    Text(api.instanceStatus)
                        .font(.system(size: 11)).foregroundColor(Theme.text3).lineLimit(1)
                }
                Spacer()
                Button {
                    Task { await api.resetAndFind() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.accent).font(.system(size: 14))
                }
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("Публичный инстанс (fallback)")
                .foregroundColor(Theme.text3).font(.system(size: 11))
        }
    }

    // MARK: - Features
    private var featuresSection: some View {
        Section {
            Toggle(isOn: $sponsorBlockEnabled) {
                Label("SponsorBlock", systemImage: "forward.fill")
                    .foregroundColor(Theme.text).font(.system(size: 13))
            }
            .tint(Theme.accent)
            .onChange(of: sponsorBlockEnabled) { _, v in UserDefaults.standard.set(v, forKey: "sponsorBlockEnabled") }
            .listRowBackground(Theme.bg2).listRowSeparatorTint(Color.white.opacity(0.06))

            Toggle(isOn: $returnDislikeEnabled) {
                Label("Показывать дизлайки", systemImage: "hand.thumbsdown")
                    .foregroundColor(Theme.text).font(.system(size: 13))
            }
            .tint(Theme.accent)
            .onChange(of: returnDislikeEnabled) { _, v in UserDefaults.standard.set(v, forKey: "returnDislikeEnabled") }
            .listRowBackground(Theme.bg2).listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("Функции").foregroundColor(Theme.text3).font(.system(size: 11))
        }
    }

    // MARK: - History
    private var historySection: some View {
        Section {
            Button { showHistory = true } label: {
                Label("История просмотров", systemImage: "clock")
                    .foregroundColor(Theme.text).font(.system(size: 13))
            }
            .listRowBackground(Theme.bg2).listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("Данные").foregroundColor(Theme.text3).font(.system(size: 11))
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Версия").font(.system(size: 13)).foregroundColor(Theme.text)
                Spacer()
                Text("1.0.0").font(.system(size: 13)).foregroundColor(Theme.text3)
            }
            .listRowBackground(Theme.bg2).listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("О приложении").foregroundColor(Theme.text3).font(.system(size: 11))
        }
    }
}
