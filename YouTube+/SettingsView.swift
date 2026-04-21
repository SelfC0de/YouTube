import SwiftUI

struct SettingsView: View {
    @StateObject private var api = InvidiousAPI.shared
    @State private var pingResults: [String: Bool] = [:]
    @State private var isPinging = false
    @State private var showHistory = false
    @State private var sponsorBlockEnabled = UserDefaults.standard.bool(forKey: "sponsorBlockEnabled")
    @State private var returnDislikeEnabled = UserDefaults.standard.bool(forKey: "returnDislikeEnabled") == false ? true : UserDefaults.standard.bool(forKey: "returnDislikeEnabled")

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    instancesSection
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

    private var instancesSection: some View {
        Section {
            ForEach(InvidiousAPI.instances, id: \.self) { instance in
                Button { api.setInstance(instance) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instance.replacingOccurrences(of: "https://", with: ""))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.text)
                            if let ok = pingResults[instance] {
                                Text(ok ? "Доступен" : "Недоступен")
                                    .font(.system(size: 11))
                                    .foregroundColor(ok ? Theme.green : Theme.accent)
                            }
                        }
                        Spacer()
                        if api.currentInstance == instance {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.accent)
                        }
                    }
                }
                .listRowBackground(Theme.bg2)
                .listRowSeparatorTint(Color.white.opacity(0.06))
            }

            Button {
                isPinging = true
                Task {
                    for instance in InvidiousAPI.instances {
                        let ok = await api.pingInstance(instance)
                        pingResults[instance] = ok
                    }
                    isPinging = false
                }
            } label: {
                HStack {
                    Label("Проверить все", systemImage: "network")
                        .foregroundColor(Theme.accent)
                        .font(.system(size: 13))
                    if isPinging { Spacer(); ProgressView().tint(Theme.accent).scaleEffect(0.8) }
                }
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("Invidious инстанс")
                .foregroundColor(Theme.text3)
                .font(.system(size: 11))
        }
    }

    private var featuresSection: some View {
        Section {
            Toggle(isOn: $sponsorBlockEnabled) {
                Label("SponsorBlock", systemImage: "forward.fill")
                    .foregroundColor(Theme.text)
                    .font(.system(size: 13))
            }
            .tint(Theme.accent)
            .onChange(of: sponsorBlockEnabled) { _, v in
                UserDefaults.standard.set(v, forKey: "sponsorBlockEnabled")
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))

            Toggle(isOn: $returnDislikeEnabled) {
                Label("Показывать дизлайки", systemImage: "hand.thumbsdown")
                    .foregroundColor(Theme.text)
                    .font(.system(size: 13))
            }
            .tint(Theme.accent)
            .onChange(of: returnDislikeEnabled) { _, v in
                UserDefaults.standard.set(v, forKey: "returnDislikeEnabled")
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("Функции")
                .foregroundColor(Theme.text3)
                .font(.system(size: 11))
        }
    }

    private var historySection: some View {
        Section {
            Button { showHistory = true } label: {
                Label("История просмотров", systemImage: "clock")
                    .foregroundColor(Theme.text)
                    .font(.system(size: 13))
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("Данные")
                .foregroundColor(Theme.text3)
                .font(.system(size: 11))
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Версия").font(.system(size: 13)).foregroundColor(Theme.text)
                Spacer()
                Text("1.0.0").font(.system(size: 13)).foregroundColor(Theme.text3)
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))

            HStack {
                Text("Бэкенд").font(.system(size: 13)).foregroundColor(Theme.text)
                Spacer()
                Text("Invidious API").font(.system(size: 13)).foregroundColor(Theme.text3)
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("О приложении")
                .foregroundColor(Theme.text3)
                .font(.system(size: 11))
        }
    }
}
