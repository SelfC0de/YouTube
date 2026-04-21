import SwiftUI
import SwiftData
import AVKit

struct DownloadsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DownloadedVideo.downloadedAt, order: .reverse) private var downloads: [DownloadedVideo]
    @StateObject private var dm = DownloadManager.shared
    @State private var playingVideo: DownloadedVideo?

    var totalSize: String {
        let bytes = downloads.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if downloads.isEmpty && dm.activeDownloads.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            storageCard
                            activeDownloadsSection
                            completedSection
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Загрузки")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bg2, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { note in
            guard let info = note.userInfo else { return }
            let item = DownloadedVideo(
                videoId: info["videoId"] as? String ?? "",
                title: info["title"] as? String ?? "",
                channelName: info["channel"] as? String ?? "",
                thumbnailURL: info["thumb"] as? String ?? "",
                duration: info["duration"] as? Int ?? 0,
                fileURL: info["fileURL"] as? String ?? "",
                fileSize: info["fileSize"] as? Int64 ?? 0,
                quality: info["quality"] as? String ?? ""
            )
            context.insert(item)
            try? context.save()
        }
        .sheet(item: $playingVideo) { vid in
            LocalPlayerView(video: vid)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 52))
                .foregroundColor(Theme.text3)
            Text("Нет загрузок")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.text2)
            Text("Скачанные видео появятся здесь")
                .font(.system(size: 14))
                .foregroundColor(Theme.text3)
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Хранилище")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text3)
                Spacer()
                Text(totalSize)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text2)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.bg3).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing))
                        .frame(width: min(geo.size.width * 0.4, geo.size.width), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(14)
        .background(Theme.bg2)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var activeDownloadsSection: some View {
        if !dm.activeDownloads.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Загружается")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text3)
                    .padding(.horizontal, 16)

                ForEach(Array(dm.activeDownloads.values), id: \.videoId) { task in
                    activeDownloadRow(task)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func activeDownloadRow(_ task: DownloadManager.DownloadTask) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.bg3).frame(width: 80, height: 48)
                CircularProgress(progress: task.progress)
                    .frame(width: 28, height: 28)
                Text("\(Int(task.progress * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                Text("Загрузка...")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text3)
            }
            Spacer()
            Button { DownloadManager.shared.cancel(videoId: task.videoId) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.text3)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !downloads.isEmpty {
                Text("Скачано")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text3)
                    .padding(.horizontal, 16)
            }
            ForEach(downloads) { video in
                downloadRow(video)
            }
        }
    }

    private func downloadRow(_ video: DownloadedVideo) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { img in
                img.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Theme.bg3)
            }
            .frame(width: 80, height: 48)
            .cornerRadius(10)
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.green)
                    .font(.system(size: 14))
                    .background(Circle().fill(Theme.bg).padding(1))
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                Text("\(video.quality) · \(ByteCountFormatter.string(fromByteCount: video.fileSize, countStyle: .file))")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text3)
            }
            Spacer()
            Button { playingVideo = video } label: {
                Image(systemName: "play.fill")
                    .foregroundColor(Theme.text2)
                    .font(.system(size: 13))
                    .frame(width: 32, height: 32)
                    .background(Theme.bg3)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete(video) } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func delete(_ video: DownloadedVideo) {
        try? FileManager.default.removeItem(atPath: video.fileURL)
        context.delete(video)
        try? context.save()
    }
}

// MARK: - Local player
struct LocalPlayerView: View {
    let video: DownloadedVideo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = URL(string: "file://\(video.fileURL)") {
                VideoPlayer(player: AVPlayer(url: url))
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.5))
                            .cornerRadius(10)
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
    }
}
