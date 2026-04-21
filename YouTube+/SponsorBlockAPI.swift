import Foundation

final class SponsorBlockAPI {
    static let shared = SponsorBlockAPI()
    private let base = "https://sponsor.ajay.app/api"
    private let session = DoHResolver.shared.makeSession()
    private init() {}

    func segments(videoId: String) async -> [SponsorSegment] {
        guard let url = URL(string: "\(base)/skipSegments?videoID=\(videoId)&categories=[\"sponsor\",\"intro\",\"outro\",\"selfpromo\"]") else { return [] }
        do {
            let (data, _) = try await session.data(from: url)
            return try JSONDecoder().decode([SponsorSegment].self, from: data)
        } catch {
            return []
        }
    }
}
