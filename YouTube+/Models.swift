import Foundation
import SwiftData

@Model
final class WatchHistoryItem {
    var videoId: String
    var title: String
    var channelName: String
    var thumbnailURL: String
    var duration: Int
    var watchedAt: Date
    var watchedSeconds: Int

    init(videoId: String, title: String, channelName: String, thumbnailURL: String, duration: Int, watchedSeconds: Int = 0) {
        self.videoId = videoId
        self.title = title
        self.channelName = channelName
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.watchedAt = Date()
        self.watchedSeconds = watchedSeconds
    }
}

@Model
final class LocalSubscription {
    var channelId: String
    var channelName: String
    var thumbnailURL: String
    var addedAt: Date

    init(channelId: String, channelName: String, thumbnailURL: String = "") {
        self.channelId = channelId
        self.channelName = channelName
        self.thumbnailURL = thumbnailURL
        self.addedAt = Date()
    }
}

@Model
final class DownloadedVideo {
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
        self.videoId = videoId
        self.title = title
        self.channelName = channelName
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.quality = quality
        self.downloadedAt = Date()
    }
}

// MARK: - API Models
struct InvidiousVideo: Codable, Identifiable {
    let videoId: String
    let title: String
    let author: String
    let authorId: String
    let videoThumbnails: [Thumbnail]
    let lengthSeconds: Int
    let viewCount: Int
    let published: Int
    let description: String?

    var id: String { videoId }
    var bestThumbnail: String { videoThumbnails.first(where: { $0.quality == "medium" })?.url ?? videoThumbnails.first?.url ?? "" }
    var viewCountFormatted: String { viewCount.formatted(.number.notation(.compactName)) }
    var publishedFormatted: String {
        let date = Date(timeIntervalSince1970: TimeInterval(published))
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(Int(diff/60)) мин. назад" }
        if diff < 86400 { return "\(Int(diff/3600)) ч. назад" }
        if diff < 2592000 { return "\(Int(diff/86400)) дн. назад" }
        return "\(Int(diff/2592000)) мес. назад"
    }
    var durationFormatted: String {
        let h = lengthSeconds / 3600
        let m = (lengthSeconds % 3600) / 60
        let s = lengthSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

struct Thumbnail: Codable {
    let quality: String
    let url: String
    let width: Int?
    let height: Int?
}

struct InvidiousChannel: Codable, Identifiable {
    let authorId: String
    let author: String
    let authorThumbnails: [Thumbnail]
    let subCount: Int?
    let description: String?

    var id: String { authorId }
    var thumbnail: String { authorThumbnails.last?.url ?? "" }
}

struct InvidiousVideoDetail: Codable {
    let videoId: String
    let title: String
    let author: String
    let authorId: String
    let videoThumbnails: [Thumbnail]
    let lengthSeconds: Int
    let viewCount: Int
    let likeCount: Int
    let description: String
    let adaptiveFormats: [AdaptiveFormat]
    let formatStreams: [FormatStream]
    let recommendedVideos: [InvidiousVideo]

    var bestThumbnail: String { videoThumbnails.first(where: { $0.quality == "medium" })?.url ?? videoThumbnails.first?.url ?? "" }
    var durationFormatted: String {
        let h = lengthSeconds / 3600
        let m = (lengthSeconds % 3600) / 60
        let s = lengthSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

struct AdaptiveFormat: Codable, Identifiable {
    let index: String?
    let bitrate: String?
    let url: String
    let itag: String
    let type: String
    let encoding: String?
    let audioQuality: String?
    let audioSampleRate: Int?
    let audioChannels: Int?
    let resolution: String?
    let qualityLabel: String?

    var id: String { itag }
    var isVideo: Bool { type.contains("video") }
    var isAudio: Bool { type.contains("audio") }
    var displayLabel: String { qualityLabel ?? audioQuality ?? itag }
}

struct FormatStream: Codable, Identifiable {
    let url: String
    let itag: String
    let type: String
    let quality: String
    let qualityLabel: String
    let resolution: String

    var id: String { itag }
}

struct SponsorSegment: Codable {
    let segment: [Double]
    let category: String
    let UUID: String
}

struct DislikeData: Codable {
    let likes: Int
    let dislikes: Int
    let rating: Double
    let viewCount: Int
}
