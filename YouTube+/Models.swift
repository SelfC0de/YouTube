import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model final class WatchHistoryItem {
    var videoId: String
    var title: String
    var channelName: String
    var thumbnailURL: String
    var duration: Int
    var watchedAt: Date
    var watchedSeconds: Int

    init(videoId: String, title: String, channelName: String, thumbnailURL: String, duration: Int, watchedSeconds: Int = 0) {
        self.videoId = videoId; self.title = title; self.channelName = channelName
        self.thumbnailURL = thumbnailURL; self.duration = duration
        self.watchedAt = Date(); self.watchedSeconds = watchedSeconds
    }
}

@Model final class LocalSubscription {
    var channelId: String
    var channelName: String
    var thumbnailURL: String
    var addedAt: Date

    init(channelId: String, channelName: String, thumbnailURL: String = "") {
        self.channelId = channelId; self.channelName = channelName
        self.thumbnailURL = thumbnailURL; self.addedAt = Date()
    }
}

@Model final class DownloadedVideo {
    var videoId: String
    var title: String
    var channelName: String
    var thumbnailURL: String
    var duration: Int
    var fileURL: String
    var fileSize: Int64
    var quality: String
    var downloadedAt: Date

    init(videoId: String, title: String, channelName: String, thumbnailURL: String, duration: Int, fileURL: String, fileSize: Int64, quality: String) {
        self.videoId = videoId; self.title = title; self.channelName = channelName
        self.thumbnailURL = thumbnailURL; self.duration = duration; self.fileURL = fileURL
        self.fileSize = fileSize; self.quality = quality; self.downloadedAt = Date()
    }
}

// MARK: - Thumbnail
struct Thumbnail: Codable {
    let quality: String?
    let url: String
    let width: Int?
    let height: Int?
}

// MARK: - InvidiousVideo (search/trending)
struct InvidiousVideo: Codable, Identifiable {
    let videoId: String
    let title: String
    let author: String
    let authorId: String?
    let videoThumbnails: [Thumbnail]?
    let lengthSeconds: Int?
    let viewCount: Int?
    let published: Int?
    let description: String?

    var id: String { videoId }

    var bestThumbnail: String {
        guard let thumbs = videoThumbnails else { return "" }
        return thumbs.first(where: { $0.quality == "medium" })?.url
            ?? thumbs.first(where: { $0.quality == "high" })?.url
            ?? thumbs.first?.url ?? ""
    }

    var viewCountFormatted: String {
        guard let v = viewCount else { return "" }
        return v.formatted(.number.notation(.compactName))
    }

    var publishedFormatted: String {
        guard let p = published else { return "" }
        let diff = Date().timeIntervalSince(Date(timeIntervalSince1970: TimeInterval(p)))
        if diff < 3600 { return "\(Int(diff/60)) мин. назад" }
        if diff < 86400 { return "\(Int(diff/3600)) ч. назад" }
        if diff < 2592000 { return "\(Int(diff/86400)) дн. назад" }
        return "\(Int(diff/2592000)) мес. назад"
    }

    var durationFormatted: String? {
        guard let s = lengthSeconds, s > 0 else { return nil }
        let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - InvidiousVideoDetail
struct InvidiousVideoDetail: Codable {
    let videoId: String
    let title: String
    let author: String
    let authorId: String?
    let videoThumbnails: [Thumbnail]?
    let lengthSeconds: Int?
    let viewCount: Int?
    let likeCount: Int?
    let description: String?
    let hlsUrl: String?          // HLS m3u8 manifest — best option for AVPlayer
    let dashUrl: String?         // DASH manifest — fallback
    let adaptiveFormats: [AdaptiveFormat]?
    let formatStreams: [FormatStream]?
    let recommendedVideos: [InvidiousVideo]?

    var bestThumbnail: String {
        guard let thumbs = videoThumbnails else { return "" }
        return thumbs.first(where: { $0.quality == "medium" })?.url ?? thumbs.first?.url ?? ""
    }

    var durationFormatted: String {
        let s = lengthSeconds ?? 0
        let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    var safeAdaptiveFormats: [AdaptiveFormat] { adaptiveFormats ?? [] }
    var safeFormatStreams: [FormatStream] { formatStreams ?? [] }
    var safeRecommended: [InvidiousVideo] { recommendedVideos ?? [] }
}

// MARK: - AdaptiveFormat
struct AdaptiveFormat: Codable, Identifiable {
    let url: String
    let itag: String?
    let type: String?
    let encoding: String?
    let audioQuality: String?
    let audioSampleRate: Int?
    let audioChannels: Int?
    let resolution: String?
    let qualityLabel: String?
    let bitrate: String?
    let fps: Int?

    var id: String { itag ?? url }
    var isVideo: Bool { type?.contains("video") ?? false }
    var isAudio: Bool { type?.contains("audio") ?? false }
}

// MARK: - FormatStream
struct FormatStream: Codable, Identifiable {
    let url: String
    let itag: String?
    let type: String?
    let quality: String?
    let qualityLabel: String?
    let resolution: String?
    let fps: Int?
    let container: String?
    let encoding: String?

    var id: String { itag ?? url }
    var displayLabel: String { qualityLabel ?? quality ?? "Unknown" }
}
// MARK: - InvidiousChannel
struct InvidiousChannel: Codable, Identifiable {
    let authorId: String
    let author: String
    let authorThumbnails: [Thumbnail]?
    let subCount: Int?
    let description: String?

    var id: String { authorId }
    var thumbnail: String { authorThumbnails?.last?.url ?? "" }
}

// MARK: - SponsorBlock
struct SponsorSegment: Codable {
    let segment: [Double]
    let category: String
    let UUID: String
}

// MARK: - Return Dislike
struct DislikeData: Codable {
    let likes: Int
    let dislikes: Int
    let rating: Double?
    let viewCount: Int?
}
