import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Главная", systemImage: "house.fill") }
                .tag(0)

            SearchView()
                .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
                .tag(1)

            SubscriptionsView()
                .tabItem { Label("Подписки", systemImage: "play.square.stack.fill") }
                .tag(2)

            DownloadsView()
                .tabItem { Label("Загрузки", systemImage: "arrow.down.circle.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Theme.accent)
        .background(Theme.bg)
        .onAppear { applyTabBarAppearance() }
    }

    private func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.bg2)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.06)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
