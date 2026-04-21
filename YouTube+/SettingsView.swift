import SwiftUI

struct SettingsView: View {
    @StateObject private var api = InvidiousAPI.shared
    @State private var showHistory = false
    @State private var sponsorBlockEnabled = UserDefaults.standard.bool(forKey: "sponsorBlockEnabled")
    @State private var returnDislikeEnabled: Bool = {
        let val = UserDefaults.standard.object(forKey: "returnDislikeEnabled")
        return val == nil ? true : UserDefaults.standard.bool(forKey: "returnDislikeEnabled")
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
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

    private var statusSection: some View {
        Section {
            HStack(spacing: 10) {
                Circle()
                    .fill(api.currentInstance.isEmpty ? Theme.text3 : Theme.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: api.currentInstance.isEmpty ? .clear : Theme.green, radius: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(api.currentInstance.isEmpty ? "Поиск инстанса..." : "Подключено")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.text)
                    Text(api.instanceStatus)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    Task {
                        api.currentInstance = ""
                        await api.resetAndFind()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.accent)
                        .font(.system(size: 14))
                }
            }
            .listRowBackground(Theme.bg2)
            .listRowSeparatorTint(Color.white.opacity(0.06))
        } header: {
            Text("Invidious")
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
