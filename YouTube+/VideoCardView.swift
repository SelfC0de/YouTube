import SwiftUI

struct VideoCardView: View {
    let video: InvidiousVideo
    var compact: Bool = false

    var body: some View {
        if compact { compactCard } else { fullCard }
    }

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailFull
            HStack(alignment: .top, spacing: 10) {
                authorAvatar(name: video.author)
                VStack(alignment: .leading, spacing: 3) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                    Text("\(video.author) · \(video.viewCountFormatted) · \(video.publishedFormatted)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                }
                Spacer()
                Image(systemName: "ellipsis").font(.system(size: 14)).foregroundColor(Theme.text3)
            }
            .padding(12)
        }
        .cardStyle()
    }

    private var thumbnailFull: some View {
        ZStack(alignment: .bottomTrailing) {
            ProxiedImage(url: video.bestThumbnail)
                .frame(height: 150)
                .clipped()
            if let d = video.durationFormatted {
                Text(d).font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.8)).cornerRadius(6).padding(8)
            }
        }
    }

    private var compactCard: some View {
        HStack(spacing: 12) {
            thumbnailCompact
            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text).lineLimit(2)
                Text("\(video.author) · \(video.viewCountFormatted)")
                    .font(.system(size: 10)).foregroundColor(Theme.text3)
            }
            Spacer()
            Image(systemName: "ellipsis").font(.system(size: 13)).foregroundColor(Theme.text3)
        }
        .padding(10)
        .cardStyle()
    }

    private var thumbnailCompact: some View {
        ZStack(alignment: .bottomTrailing) {
            ProxiedImage(url: video.bestThumbnail)
                .frame(width: 90, height: 54)
                .cornerRadius(10).clipped()
            if let d = video.durationFormatted {
                Text(d).font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(.black.opacity(0.8)).cornerRadius(4).padding(4)
            }
        }
    }

    private func authorAvatar(name: String) -> some View {
        Circle()
            .fill(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 32, height: 32)
            .overlay(Text(String(name.prefix(1))).font(.system(size: 13, weight: .bold)).foregroundColor(.white))
    }
}

// Загружает изображения через свой сервер-прокси с поддержкой самоподписанного сертификата
struct ProxiedImage: View {
    let url: String
    @State private var image: UIImage?
    @State private var loading = true

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.urlCache = URLCache(memoryCapacity: 50*1024*1024, diskCapacity: 200*1024*1024)
        return URLSession(configuration: cfg, delegate: TrustAllImageDelegate(), delegateQueue: nil)
    }()

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.bg3)
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } else if loading {
                ProgressView().scaleEffect(0.5).tint(Theme.text3)
            } else {
                Image(systemName: "play.rectangle")
                    .foregroundColor(Theme.text3)
                    .font(.system(size: 20))
            }
        }
        .task(id: url) { await loadImage() }
    }

    private func loadImage() async {
        loading = true
        image = nil

        // Пробуем прямой URL сначала
        if let img = await fetch(url) {
            image = img; loading = false; return
        }
        // Fallback: через прокси
        if let img = await fetch(proxyURL) {
            image = img; loading = false; return
        }
        loading = false
    }

    private var proxyURL: String {
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        return "https://selfcode-api.win/proxy/thumbnails?url=\(encoded)"
    }

    private func fetch(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        // Проверяем кеш
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        if let cached = Self.session.configuration.urlCache?.cachedResponse(for: req),
           let img = UIImage(data: cached.data) { return img }
        do {
            let (data, resp) = try await Self.session.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return UIImage(data: data)
        } catch { return nil }
    }
}

private final class TrustAllImageDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
