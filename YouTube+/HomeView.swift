import SwiftUI

struct HomeView: View {
    @StateObject private var api = InvidiousAPI.shared
    @State private var videos: [InvidiousVideo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedChip = "Главная"

    let chips = ["Главная", "Музыка", "Игры", "Новости", "Технологии"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        instanceBadge
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
                                    .background(Theme.accent)
                                    .foregroundColor(.white)
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
        }
        .task { await loadTrending() }
    }

    private var instanceBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(videos.isEmpty ? Theme.text3 : Theme.green)
                .frame(width: 6, height: 6)
                .shadow(color: videos.isEmpty ? .clear : Theme.green, radius: 3)
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
                .font(.system(size: 20, weight: .black))
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
        errorMessage = nil
        do {
            videos = try await api.trending()
            if videos.isEmpty { errorMessage = "Нет видео. Попробуйте позже." }
        } catch {
            errorMessage = "Не удалось загрузить.\n\(error.localizedDescription)"
        }
        isLoading = false
    }
}
