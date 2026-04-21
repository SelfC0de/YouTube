import SwiftUI
import AVKit
import SwiftData

struct PlayerView: View {
    let video: InvidiousVideo

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PlayerViewModel()
    @State private var showQualitySheet = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                playerArea
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        infoSection
                        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                        recommendedSection
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task { await vm.load(video: video, context: context) }
        .sheet(isPresented: $showQualitySheet) { qualitySheet }
    }

    // MARK: - Player area
    private var playerArea: some View {
        ZStack {
            if let player = vm.player {
                VideoPlayer(player: player)
                    .frame(height: 220)
                    .background(Color.black)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 220)
                    .overlay(ProgressView().tint(Theme.accent))
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.5))
                            .cornerRadius(10)
                    }
                    Spacer()
                    Button { vm.togglePiP() } label: {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.5))
                            .cornerRadius(10)
                    }
                }
                .padding(12)
                Spacer()
            }
            .frame(height: 220)
        }
    }

    // MARK: - Info section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(video.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.text)
                .padding(.top, 14)

            HStack(spacing: 4) {
                Text(video.author)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text2)
                Text("·")
                    .foregroundColor(Theme.text3)
                Text(video.viewCountFormatted)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text3)
                if let dl = vm.dislikeData {
                    Text("·")
                        .foregroundColor(Theme.text3)
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.text3)
                    Text(dl.likes.formatted(.number.notation(.compactName)))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.text3)
                    Text(dl.dislikes.formatted(.number.notation(.compactName)))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                }
            }

            // Action buttons
            HStack(spacing: 10) {
                downloadButton
                Button {
                    showQualitySheet = true
                } label: {
                    Label(vm.selectedQuality, systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(Theme.bg2)
                        .foregroundColor(Theme.text2)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                ShareLink(item: URL(string: "https://youtube.com/watch?v=\(video.videoId)")!) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(Theme.bg2)
                        .foregroundColor(Theme.text2)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
            }

            if let sponsorNote = vm.sponsorNote {
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.accent)
                    Text(sponsorNote)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.text2)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.accent.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var downloadButton: some View {
        if let progress = vm.downloadProgress {
            Button { DownloadManager.shared.cancel(videoId: video.videoId) } label: {
                HStack(spacing: 6) {
                    CircularProgress(progress: progress)
                        .frame(width: 16, height: 16)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(Theme.accent.opacity(0.15))
                .foregroundColor(Theme.accent)
                .cornerRadius(12)
            }
        } else if vm.isDownloaded {
            Label("Скачано", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(Theme.green.opacity(0.12))
                .foregroundColor(Theme.green)
                .cornerRadius(12)
        } else {
            Button {
                guard let detail = vm.detail else { return }
                DownloadManager.shared.download(detail: detail, quality: vm.selectedQuality, context: context)
            } label: {
                Label("Скачать", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 4)
            }
            .disabled(vm.detail == nil)
        }
    }

    // MARK: - Quality sheet
    private var qualitySheet: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    Section("Видео") {
                        ForEach(vm.videoQualities, id: \.self) { q in
                            Button {
                                vm.selectQuality(q)
                                showQualitySheet = false
                            } label: {
                                HStack {
                                    Text(q)
                                        .foregroundColor(vm.selectedQuality == q ? Theme.accent : Theme.text)
                                    Spacer()
                                    if vm.selectedQuality == q {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Theme.accent)
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                            }
                            .listRowBackground(Theme.bg2)
                        }
                    }
                    Section("Аудио") {
                        ForEach(vm.audioQualities, id: \.self) { q in
                            Button {
                                vm.selectQuality(q)
                                showQualitySheet = false
                            } label: {
                                HStack {
                                    Text(q)
                                        .foregroundColor(vm.selectedQuality == q ? Theme.accent : Theme.text)
                                    Spacer()
                                    if vm.selectedQuality == q {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Theme.accent)
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                            }
                            .listRowBackground(Theme.bg2)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Качество")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg2, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { showQualitySheet = false }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.bg)
    }

    // MARK: - Recommended
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Похожие видео")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.text2)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            ForEach(vm.recommended) { rec in
                NavigationLink(destination: PlayerView(video: rec)) {
                    VideoCardView(video: rec, compact: true)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 20)
    }
}

// MARK: - ViewModel
@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var detail: InvidiousVideoDetail?
    @Published var recommended: [InvidiousVideo] = []
    @Published var dislikeData: DislikeData?
    @Published var sponsorNote: String?
    @Published var selectedQuality = "720p"
    @Published var videoQualities: [String] = []
    @Published var audioQualities: [String] = ["128 kbps", "320 kbps"]
    @Published var downloadProgress: Double?
    @Published var isDownloaded = false

    private var pipController: AVPictureInPictureController?
    private var sponsorSegments: [SponsorSegment] = []
    private var timeObserver: Any?

    func load(video: InvidiousVideo, context: ModelContext) async {
        isDownloaded = DownloadManager.shared.isDownloaded(videoId: video.videoId, context: context)

        async let detailTask = InvidiousAPI.shared.videoDetail(videoId: video.videoId)
        async let sponsorTask = SponsorBlockAPI.shared.segments(videoId: video.videoId)
        async let dislikeTask = ReturnDislikeAPI.shared.dislikes(videoId: video.videoId)

        sponsorSegments = await sponsorTask
        dislikeData = await dislikeTask

        do {
            let d = try await detailTask
            detail = d
            recommended = d.recommendedVideos

            buildQualityList(from: d)
            await playStream(detail: d, quality: selectedQuality)
            setupSponsorBlock()
            saveHistory(video: video, context: context)
        } catch {}
    }

    private func buildQualityList(from detail: InvidiousVideoDetail) {
        var qualities: [String] = []
        let labels = detail.adaptiveFormats.compactMap { $0.isVideo ? $0.qualityLabel : nil }
        let unique = Array(NSOrderedSet(array: labels)) as? [String] ?? []
        let order = ["144p", "240p", "360p", "480p", "720p", "720p60", "1080p", "1080p60", "1440p", "2160p", "4K"]
        qualities = order.filter { unique.contains($0) }
        if qualities.isEmpty {
            qualities = detail.formatStreams.map { $0.qualityLabel }
        }
        videoQualities = qualities
        if let best = ["720p", "720p60", "480p", "360p"].first(where: { qualities.contains($0) }) {
            selectedQuality = best
        } else {
            selectedQuality = qualities.first ?? "360p"
        }
    }

    func selectQuality(_ quality: String) {
        selectedQuality = quality
        guard let detail else { return }
        Task { await playStream(detail: detail, quality: quality) }
    }

    private func playStream(detail: InvidiousVideoDetail, quality: String) async {
        let urlString: String
        if quality.contains("kbps") {
            guard let audio = detail.adaptiveFormats.first(where: { $0.isAudio }) else { return }
            urlString = audio.url
        } else {
            if let fmt = detail.adaptiveFormats.first(where: { $0.qualityLabel == quality && $0.isVideo }) {
                urlString = fmt.url
            } else if let fallback = detail.formatStreams.first(where: { $0.qualityLabel == quality }) {
                urlString = fallback.url
            } else if let any = detail.formatStreams.first {
                urlString = any.url
            } else { return }
        }

        guard let url = URL(string: urlString) else { return }
        let newPlayer = AVPlayer(url: url)
        player = newPlayer

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let layer = AVPlayerLayer(player: newPlayer)
            pipController = AVPictureInPictureController(playerLayer: layer)
        }
        newPlayer.play()
    }

    func togglePiP() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }

    private func setupSponsorBlock() {
        guard !sponsorSegments.isEmpty, let player else { return }
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let current = time.seconds
            for seg in self.sponsorSegments {
                guard seg.segment.count == 2 else { continue }
                if current >= seg.segment[0] && current < seg.segment[1] {
                    player.seek(to: CMTime(seconds: seg.segment[1], preferredTimescale: 600))
                    self.sponsorNote = "Пропущена реклама (\(seg.category))"
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        self.sponsorNote = nil
                    }
                    break
                }
            }
        }
    }

    private func saveHistory(video: InvidiousVideo, context: ModelContext) {
        let item = WatchHistoryItem(
            videoId: video.videoId,
            title: video.title,
            channelName: video.author,
            thumbnailURL: video.bestThumbnail,
            duration: video.lengthSeconds
        )
        context.insert(item)
        try? context.save()
    }
}

// MARK: - Circular progress
struct CircularProgress: View {
    var progress: Double
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}
