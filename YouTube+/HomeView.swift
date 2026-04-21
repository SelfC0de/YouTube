import SwiftUI

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct HomeView: View {
    @StateObject private var api = InvidiousAPI.shared
    @State private var videos: [InvidiousVideo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedChip = "Главная"
    @State private var showAuthSheet = false

    let chips = ["Главная", "Музыка", "Игры", "Новости", "Технологии"]
    let chipQueries = ["популярное 2026", "music hits 2026", "gaming 2026", "новости 2026", "tech review 2026"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        chipsRow
                        if isLoading {
                            ProgressView().tint(Theme.accent).padding(.top, 60)
                        } else if let err = errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.text3)
                                Text(err)
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.text3)
                                    .multilineTextAlignment(.center)
                                Button("Повторить") { Task { await loadTrending() } }
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(Theme.accent).foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(videos.enumerated()), id: \.element.id) { i, video in
                                    NavigationLink(destination: PlayerView(video: video)) {
                                        VideoCardView(video: video, compact: i > 0)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("YouTube+")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(Theme.bg2, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showAuthSheet) { AuthSheet() }
        }
        .task { await loadTrending() }
    }

    private var instanceBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(videos.isEmpty && errorMessage != nil ? Theme.accent : Theme.green)
                .frame(width: 6, height: 6)
                .shadow(color: Theme.green, radius: 3)
            Text(api.instanceStatus)
                .font(.system(size: 11))
                .foregroundColor(Theme.text3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.element) { i, chip in
                    Button(chip) {
                        selectedChip = chip
                        Task { await loadChip(index: i) }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(selectedChip == chip ? Theme.accent : Theme.bg2)
                    .foregroundColor(selectedChip == chip ? .white : Theme.text2)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: selectedChip == chip ? 0 : 1))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("YouTube+")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing))
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showAuthSheet = true
            } label: {
                Image(systemName: AuthManager.shared.isLoggedIn ? "person.circle.fill" : "person.circle")
                    .foregroundColor(AuthManager.shared.isLoggedIn ? Theme.accent : Theme.text2)
                    .font(.system(size: 18))
            }
        }
    }

    private func loadChip(index: Int) async {
        isLoading = true
        errorMessage = nil
        let query = chipQueries[safe: index] ?? chipQueries[0]
        do {
            videos = try await api.search(query: query, page: 1)
            if videos.isEmpty { errorMessage = "Нет видео. Попробуйте позже." }
        } catch {
            errorMessage = "Не удалось загрузить."
        }
        isLoading = false
    }

    private func loadTrending() async {
        isLoading = true
        errorMessage = nil

        // Trending сломан на всех публичных инстансах — используем поиск популярного
        let queries = ["популярное", "music 2026", "новости сегодня", "gaming", "tech 2026"]
        let query = queries[Int.random(in: 0..<queries.count)]

        do {
            videos = try await api.search(query: query, page: 1)
            if videos.isEmpty { errorMessage = "Нет видео. Попробуйте позже." }
        } catch {
            // Последняя попытка — другой запрос
            do {
                videos = try await api.search(query: "youtube 2025", page: 1)
            } catch {
                errorMessage = "Не удалось загрузить.\n\(error.localizedDescription)"
            }
        }
        isLoading = false
    }
}
