import SwiftUI

struct VideoCardView: View {
    let video: InvidiousVideo
    var compact: Bool = false

    var body: some View {
        if compact {
            compactCard
        } else {
            fullCard
        }
    }

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: video.bestThumbnail)) { img in
                    img.resizable().aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Theme.bg3)
                }
                .frame(height: 150)
                .clipped()

                Text(video.durationFormatted)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.8))
                    .cornerRadius(6)
                    .padding(8)
            }

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .overlay(Text(String(video.author.prefix(1))).font(.system(size: 13, weight: .bold)).foregroundColor(.white))

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
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text3)
            }
            .padding(12)
        }
        .cardStyle()
    }

    private var compactCard: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: video.bestThumbnail)) { img in
                    img.resizable().aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Theme.bg3)
                }
                .frame(width: 90, height: 54)
                .cornerRadius(10)
                .clipped()

                Text(video.durationFormatted)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(.black.opacity(0.8))
                    .cornerRadius(4)
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                Text("\(video.author) · \(video.viewCountFormatted)")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text3)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .font(.system(size: 13))
                .foregroundColor(Theme.text3)
        }
        .padding(10)
        .cardStyle()
    }
}
