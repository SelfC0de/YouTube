import Foundation

final class SponsorBlockAPI {
    static let shared = SponsorBlockAPI()
    private let base = "https://sponsor.ajay.app/api"
    private init() {}

    func segments(videoId: String) async -> [SponsorSegment] {
        guard let url = URL(string: "\(base)/skipSegments?videoID=\(videoId)&categories=[\"sponsor\",\"intro\",\"outro\",\"selfpromo\"]") else { return [] }
        do {
            let (data, _) = try await DoHResolver.shared.dataBypassingDNS(for: url)
            return (try? JSONDecoder().decode([SponsorSegment].self, from: data)) ?? []
        } catch { return [] }
    }
}
