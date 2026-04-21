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
            CachedAsyncImage(url: video.bestThumbnail)
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
            CachedAsyncImage(url: video.bestThumbnail)
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

// Image cache wrapper — reuses URLCache, avoids redundant fetches
struct CachedAsyncImage: View {
    let url: String
    var body: some View {
        if let u = URL(string: url) {
            AsyncImage(url: u) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(16/9, contentMode: .fill)
                case .failure:
                    Rectangle().fill(Theme.bg3)
                case .empty:
                    Rectangle().fill(Theme.bg3).overlay(ProgressView().scaleEffect(0.5).tint(Theme.text3))
                @unknown default:
                    Rectangle().fill(Theme.bg3)
                }
            }
        } else {
            Rectangle().fill(Theme.bg3)
        }
    }
}
