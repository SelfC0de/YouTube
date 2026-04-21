import SwiftUI

struct SearchView: View {
    @StateObject private var api = InvidiousAPI.shared
    @State private var query = ""
    @State private var results: [InvidiousVideo] = []
    @State private var isLoading = false
    @State private var page = 1
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    if isLoading && results.isEmpty {
                        Spacer()
                        ProgressView().tint(Theme.accent)
                        Spacer()
                    } else if results.isEmpty && !query.isEmpty {
                        Spacer()
                        Text("Ничего не найдено").foregroundColor(Theme.text3)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(results) { video in
                                    NavigationLink(destination: PlayerView(video: video)) {
                                        VideoCardView(video: video, compact: true)
                                    }
                                    .buttonStyle(.plain)
                                    .onAppear {
                                        if video.id == results.last?.id { loadMore() }
                                    }
                                }
                                if isLoading {
                                    ProgressView().tint(Theme.accent).padding()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(focused ? Theme.accent : Theme.text3)
                    .font(.system(size: 14))
                TextField("Поиск видео...", text: $query)
                    .foregroundColor(Theme.text)
                    .font(.system(size: 14))
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { search() }
                if !query.isEmpty {
                    Button { query = ""; results = [] } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.text3)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Theme.bg2)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(focused ? Theme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))

            if focused {
                Button("Отмена") {
                    focused = false
                    query = ""
                    results = []
                }
                .foregroundColor(Theme.accent)
                .font(.system(size: 14))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.2), value: focused)
    }

    private func search() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        page = 1
        results = []
        isLoading = true
        Task {
            do { results = try await InvidiousAPI.shared.search(query: query, page: page) }
            catch {}
            isLoading = false
        }
    }

    private func loadMore() {
        guard !isLoading else { return }
        page += 1
        isLoading = true
        Task {
            do {
                let more = try await InvidiousAPI.shared.search(query: query, page: page)
                results.append(contentsOf: more)
            } catch {}
            isLoading = false
        }
    }
}
