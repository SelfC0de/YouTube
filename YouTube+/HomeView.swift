import SwiftUI

struct HomeView: View {
    @StateObject private var api = InvidiousAPI.shared
    @State private var videos: [InvidiousVideo] = []
    @State private var isLoading = false
    @State private var selectedChip = "Главная"
    @State private var selectedVideo: InvidiousVideo?

    let chips = ["Главная", "Музыка", "Игры", "Новости", "Технологии"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        chipsRow
                        if isLoading {
                            ProgressView().tint(Theme.accent).padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(videos.enumerated()), id: \.element.id) { i, video in
                                    NavigationLink(destination: PlayerView(video: video)) {
                                        if i == 0 {
                                            VideoCardView(video: video, compact: false)
                                        } else {
                                            VideoCardView(video: video, compact: true)
                                        }
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
        }
        .task { await loadTrending() }
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button(chip) {
                        selectedChip = chip
                        Task { await loadTrending() }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(selectedChip == chip ? Theme.accent : Theme.bg2)
                    .foregroundColor(selectedChip == chip ? .white : Theme.text2)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: selectedChip == chip ? 0 : 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("YouTube+")
                .font(.system(size: 20, weight: .black, design: .default))
                .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing))
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 8) {
                Image(systemName: "bell").foregroundColor(Theme.text2)
                Image(systemName: "person.circle").foregroundColor(Theme.text2)
            }
        }
    }

    private func loadTrending() async {
        isLoading = true
        do {
            videos = try await api.trending()
        } catch {
            videos = []
        }
        isLoading = false
    }
}
