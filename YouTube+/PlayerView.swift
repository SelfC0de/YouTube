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
        .onDisappear { vm.cleanup() }
        .sheet(isPresented: $showQualitySheet) { qualitySheet }
    }

    private var playerArea: some View {
        ZStack {
            Color.black.frame(height: 220)
            if let player = vm.player {
                VideoPlayer(player: player).frame(height: 220)
            } else if !vm.loadError.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundColor(Theme.accent).font(.system(size: 24))
                    Text(vm.loadError).font(.system(size: 11)).foregroundColor(Theme.text3).multilineTextAlignment(.center).padding(.horizontal, 20)
                }
            } else {
                ProgressView().tint(Theme.accent)
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 32, height: 32).background(.black.opacity(0.5)).cornerRadius(10)
                    }
                    Spacer()
                    Button { vm.togglePiP() } label: {
                        Image(systemName: "pip.enter").font(.system(size: 13)).foregroundColor(.white)
                            .frame(width: 32, height: 32).background(.black.opacity(0.5)).cornerRadius(10)
                    }
                }.padding(12)
                Spacer()
            }.frame(height: 220)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(video.title).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text).padding(.top, 14)

            HStack(spacing: 4) {
                Text(video.author).font(.system(size: 12)).foregroundColor(Theme.text2)
                Text("·").foregroundColor(Theme.text3)
                Text(video.viewCountFormatted).font(.system(size: 12)).foregroundColor(Theme.text3)
                if let dl = vm.dislikeData {
                    Text("·").foregroundColor(Theme.text3)
                    Image(systemName: "hand.thumbsup.fill").font(.system(size: 10)).foregroundColor(Theme.text3)
                    Text(dl.likes.formatted(.number.notation(.compactName))).font(.system(size: 11)).foregroundColor(Theme.text3)
                    Image(systemName: "hand.thumbsdown.fill").font(.system(size: 10)).foregroundColor(Theme.text3)
                    Text(dl.dislikes.formatted(.number.notation(.compactName))).font(.system(size: 11)).foregroundColor(Theme.text3)
                }
            }

            HStack(spacing: 10) {
                downloadButton
                Button { showQualitySheet = true } label: {
                    Label(vm.selectedQuality, systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 11).frame(maxWidth: .infinity)
                        .background(Theme.bg2).foregroundColor(Theme.text2).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                ShareLink(item: URL(string: "https://youtube.com/watch?v=\(video.videoId)")!) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 11).frame(maxWidth: .infinity)
                        .background(Theme.bg2).foregroundColor(Theme.text2).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
            }

            if let note = vm.sponsorNote {
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill").font(.system(size: 11)).foregroundColor(Theme.accent)
                    Text(note).font(.system(size: 12)).foregroundColor(Theme.text2)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.accent.opacity(0.08)).cornerRadius(10)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
    }

    @ViewBuilder
    private var downloadButton: some View {
        if let progress = vm.downloadProgress {
            Button { DownloadManager.shared.cancel(videoId: video.videoId) } label: {
                HStack(spacing: 6) {
                    CircularProgress(progress: progress).frame(width: 16, height: 16)
                    Text("\(Int(progress * 100))%").font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 11).frame(maxWidth: .infinity)
                .background(Theme.accent.opacity(0.15)).foregroundColor(Theme.accent).cornerRadius(12)
            }
        } else if vm.isDownloaded {
            Label("Скачано", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 11).frame(maxWidth: .infinity)
                .background(Theme.green.opacity(0.12)).foregroundColor(Theme.green).cornerRadius(12)
        } else {
            Button {
                guard let detail = vm.detail else { return }
                DownloadManager.shared.download(detail: detail, quality: vm.selectedQuality, context: context)
            } label: {
                Label("Скачать", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 11).frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).cornerRadius(12)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 4)
            }
            .disabled(vm.detail == nil)
        }
    }

    private var qualitySheet: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    if !vm.videoQualities.isEmpty {
                        Section("Видео") {
                            ForEach(vm.videoQualities, id: \.self) { q in
                                Button {
                                    vm.selectQuality(q); showQualitySheet = false
                                } label: {
                                    HStack {
                                        Text(q).foregroundColor(vm.selectedQuality == q ? Theme.accent : Theme.text)
                                        Spacer()
                                        if vm.selectedQuality == q {
                                            Image(systemName: "checkmark").foregroundColor(Theme.accent).font(.system(size: 13, weight: .semibold))
                                        }
                                    }
                                }.listRowBackground(Theme.bg2)
                            }
                        }
                    }
                    Section("Аудио") {
                        ForEach(vm.audioQualities, id: \.self) { q in
                            Button {
                                vm.selectQuality(q); showQualitySheet = false
                            } label: {
                                HStack {
                                    Text(q).foregroundColor(vm.selectedQuality == q ? Theme.accent : Theme.text)
                                    Spacer()
                                    if vm.selectedQuality == q {
                                        Image(systemName: "checkmark").foregroundColor(Theme.accent).font(.system(size: 13, weight: .semibold))
                                    }
                                }
                            }.listRowBackground(Theme.bg2)
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
                    Button("Готово") { showQualitySheet = false }.foregroundColor(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.bg)
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !vm.recommended.isEmpty {
                Text("Похожие видео").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text2)
                    .padding(.horizontal, 16).padding(.top, 14)
                ForEach(vm.recommended) { rec in
                    NavigationLink(destination: PlayerView(video: rec)) {
                        VideoCardView(video: rec, compact: true)
                    }
                    .buttonStyle(.plain).padding(.horizontal, 16)
                }
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
    @Published var selectedQuality = "360p"
    @Published var videoQualities: [String] = []
    @Published var audioQualities: [String] = ["128 kbps", "320 kbps"]
    @Published var downloadProgress: Double?
    @Published var isDownloaded = false
    @Published var loadError: String = ""

    private var pipController: AVPictureInPictureController?
    private var sponsorSegments: [SponsorSegment] = []
    private var timeObserver: Any?

    func load(video: InvidiousVideo, context: ModelContext) async {
        isDownloaded = DownloadManager.shared.isDownloaded(videoId: video.videoId, context: context)
        loadError = ""

        do {
            let d = try await InvidiousAPI.shared.videoDetail(videoId: video.videoId)
            detail = d
            recommended = d.safeRecommended

            async let sponsor = SponsorBlockAPI.shared.segments(videoId: video.videoId)
            async let dislike = ReturnDislikeAPI.shared.dislikes(videoId: video.videoId)
            sponsorSegments = await sponsor
            dislikeData = await dislike

            buildQualityList(from: d)
            await playStream(detail: d, quality: selectedQuality)
            setupSponsorBlock()
            saveHistory(video: video, context: context)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func buildQualityList(from d: InvidiousVideoDetail) {
        let order = ["144p", "240p", "360p", "480p", "720p", "720p60", "1080p", "1080p60", "1440p", "2160p"]

        var fromStreams = d.safeFormatStreams.compactMap { $0.qualityLabel }.filter { !$0.isEmpty }
        let fromAdaptive = d.safeAdaptiveFormats.filter { $0.isVideo }.compactMap { $0.qualityLabel }.filter { !$0.isEmpty }
        fromStreams += fromAdaptive

        var seen = Set<String>()
        let unique = fromStreams.filter { seen.insert($0).inserted }
        let sorted = order.filter { unique.contains($0) }
        videoQualities = sorted.isEmpty ? unique : sorted

        // HLS available — auto quality switching, set as default
        if d.hlsUrl != nil {
            if !videoQualities.contains("HLS (авто)") {
                videoQualities.insert("HLS (авто)", at: 0)
            }
            selectedQuality = "HLS (авто)"
        } else {
            let preferred = ["720p", "720p60", "480p", "360p", "240p"]
            selectedQuality = preferred.first { videoQualities.contains($0) } ?? videoQualities.first ?? "360p"
        }
    }
    }

    func selectQuality(_ quality: String) {
        selectedQuality = quality
        guard let detail else { return }
        Task {
            if quality == "HLS (авто)", let hls = detail.hlsUrl, let url = URL(string: hls) {
                start(url: url)
            } else {
                await playStream(detail: detail, quality: quality)
            }
        }
    }

    private func playStream(detail: InvidiousVideoDetail, quality: String) async {
        loadError = ""

        // Audio only
        if quality.contains("kbps") {
            let audio = detail.safeAdaptiveFormats.first(where: { $0.isAudio })
                ?? detail.safeFormatStreams.first
            if let url = audio.flatMap({ URL(string: $0.url) }) { start(url: url) }
            return
        }

        // 1. hlsUrl из поля (Invidious иногда заполняет)
        if let hls = detail.hlsUrl, let url = URL(string: hls) {
            start(url: url); return
        }

        // 2. HLS из formatStreams — itag=91 или URL содержит hls_variant
        if let hlsStream = detail.safeFormatStreams.first(where: {
            $0.itag == "91" || ($0.url.contains("hls_variant") || $0.url.contains("manifest"))
        }), let url = URL(string: hlsStream.url) {
            start(url: url); return
        }

        // 3. formatStream по выбранному качеству
        if let s = detail.safeFormatStreams.first(where: { $0.qualityLabel == quality }),
           let url = URL(string: s.url) {
            start(url: url); return
        }

        // 4. Первый formatStream (видео + аудио combined, itag=18 = 360p mp4)
        if let s = detail.safeFormatStreams.first(where: { $0.itag != "91" }),
           let url = URL(string: s.url) {
            start(url: url); return
        }

        // 5. adaptiveFormats видео
        if let f = detail.safeAdaptiveFormats.first(where: { $0.isVideo }),
           let url = URL(string: f.url) {
            start(url: url); return
        }

        loadError = "Нет доступных потоков"
    }

    private func start(url: URL) {
        let p = AVPlayer(url: url)
        player = p
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: AVPlayerLayer(player: p))
        }
        p.play()
    }

    func togglePiP() {
        guard let pip = pipController else { return }
        pip.isPictureInPictureActive ? pip.stopPictureInPicture() : pip.startPictureInPicture()
    }

    private func setupSponsorBlock() {
        guard !sponsorSegments.isEmpty, let player else { return }
        let segments = sponsorSegments
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            let cur = time.seconds
            for seg in segments {
                guard seg.segment.count == 2 else { continue }
                if cur >= seg.segment[0] && cur < seg.segment[1] {
                    player.seek(to: CMTime(seconds: seg.segment[1], preferredTimescale: 600))
                    Task { @MainActor [weak self] in
                        self?.sponsorNote = "Пропущен спонсор"
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        self?.sponsorNote = nil
                    }
                    break
                }
            }
        }
    }

    private func saveHistory(video: InvidiousVideo, context: ModelContext) {
        let item = WatchHistoryItem(videoId: video.videoId, title: video.title, channelName: video.author,
                                   thumbnailURL: video.bestThumbnail, duration: video.lengthSeconds ?? 0)
        context.insert(item)
        try? context.save()
    }

    func cleanup() {
        if let obs = timeObserver, let p = player {
            p.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        pipController = nil
    }
}

struct CircularProgress: View {
    var progress: Double
    var body: some View {
        Circle().trim(from: 0, to: progress)
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}
