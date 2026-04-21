import SwiftUI
import SwiftData

@main
struct YouTubePlusApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [WatchHistoryItem.self, LocalSubscription.self, DownloadedVideo.self])
    }
}
