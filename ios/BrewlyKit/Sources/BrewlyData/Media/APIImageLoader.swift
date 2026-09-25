import BrewlyDomain
import BrewlyNetworking
import Foundation

/// Downloads images through the API client (with the access token) and keeps them in memory.
/// Images never change, so a cached copy is always valid.
public actor APIImageLoader: ImageLoader {
    private let client: APIClient
    private let cache = NSCache<NSURL, NSData>()
    private var inFlight: [URL: Task<Data, any Error>] = [:]

    public init(client: APIClient) {
        self.client = client
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    public func imageData(for url: URL) async throws -> Data {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached as Data
        }
        if let task = inFlight[url] {
            return try await task.value
        }
        let client = client
        let task = Task { try await Self.download(url, client: client) }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let data = try await task.value
        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }

    /// Relative URLs (`/v1/media/…`) go to the API; absolute ones are fetched directly.
    private static func download(_ url: URL, client: APIClient) async throws -> Data {
        try await mappingErrors {
            if url.host == nil {
                return try await client.send(Endpoints.image(path: String(url.path.drop { $0 == "/" })))
            }
            return try await URLSession.shared.data(from: url).0
        }
    }
}
