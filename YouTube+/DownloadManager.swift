import Foundation
import SwiftData

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var activeDownloads: [String: DownloadTask] = [:]

    private var urlSession: URLSession!

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.selfcode.youtubeplus.downloads")
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    struct DownloadTask {
        var videoId: String
        var title: String
        var progress: Double
        var task: URLSessionDownloadTask?
    }

    func download(detail: InvidiousVideoDetail, quality: String, context: ModelContext) {
        let streamURL: String
        if quality.contains("kbps") {
            if let audio = detail.safeAdaptiveFormats.first(where: { $0.isAudio }) {
                streamURL = audio.url
            } else if let fallback = detail.safeFormatStreams.first {
                streamURL = fallback.url
            } else { return }
        } else {
            if let fmt = detail.safeFormatStreams.first(where: { $0.qualityLabel == quality }) {
                streamURL = fmt.url
            } else if let fmt = detail.safeAdaptiveFormats.first(where: { $0.qualityLabel == quality && $0.isVideo }) {
                streamURL = fmt.url
            } else if let fallback = detail.safeFormatStreams.first {
                streamURL = fallback.url
            } else { return }
        }

        guard let url = URL(string: streamURL) else { return }
        let task = DownloadTask(videoId: detail.videoId, title: detail.title, progress: 0, task: nil)
        activeDownloads[detail.videoId] = task

        let dlTask = urlSession.downloadTask(with: url)
        activeDownloads[detail.videoId]?.task = dlTask

        // Store metadata for completion
        UserDefaults.standard.set(detail.videoId, forKey: "dl_\(dlTask.taskIdentifier)_id")
        UserDefaults.standard.set(detail.title, forKey: "dl_\(dlTask.taskIdentifier)_title")
        UserDefaults.standard.set(detail.author, forKey: "dl_\(dlTask.taskIdentifier)_channel")
        UserDefaults.standard.set(detail.bestThumbnail, forKey: "dl_\(dlTask.taskIdentifier)_thumb")
        UserDefaults.standard.set(detail.lengthSeconds, forKey: "dl_\(dlTask.taskIdentifier)_duration")
        UserDefaults.standard.set(quality, forKey: "dl_\(dlTask.taskIdentifier)_quality")

        dlTask.resume()
    }

    func cancel(videoId: String) {
        activeDownloads[videoId]?.task?.cancel()
        activeDownloads.removeValue(forKey: videoId)
    }

    func isDownloaded(videoId: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<DownloadedVideo>(predicate: #Predicate { $0.videoId == videoId })
        return (try? context.fetch(descriptor).first) != nil
    }

    private func downloadsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskIdentifier
        let videoId = UserDefaults.standard.string(forKey: "dl_\(id)_id") ?? ""
        let title = UserDefaults.standard.string(forKey: "dl_\(id)_title") ?? ""
        let channel = UserDefaults.standard.string(forKey: "dl_\(id)_channel") ?? ""
        let thumb = UserDefaults.standard.string(forKey: "dl_\(id)_thumb") ?? ""
        let duration = UserDefaults.standard.integer(forKey: "dl_\(id)_duration")
        let quality = UserDefaults.standard.string(forKey: "dl_\(id)_quality") ?? "720p"

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(videoId)_\(quality).mp4")
        try? FileManager.default.moveItem(at: location, to: dest)

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0

        Task { @MainActor in
            // We don't have context here — use a notification pattern
            NotificationCenter.default.post(name: .downloadCompleted, object: nil, userInfo: [
                "videoId": videoId, "title": title, "channel": channel,
                "thumb": thumb, "duration": duration, "quality": quality,
                "fileURL": dest.path, "fileSize": fileSize
            ])
            self.activeDownloads.removeValue(forKey: videoId)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let id = UserDefaults.standard.string(forKey: "dl_\(downloadTask.taskIdentifier)_id") ?? ""
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.activeDownloads[id]?.progress = progress
        }
    }
}

extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
}
