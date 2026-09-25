import BrewlyDomain
import SwiftUI
import UIKit

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: (any ImageLoader)? = nil
}

public extension EnvironmentValues {
    /// Loads images from the API. `AppFeature` provides it for the whole app.
    var imageLoader: (any ImageLoader)? {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

/// An image from the API, with a crema placeholder while it loads.
public struct RemoteImage: View {
    private let url: URL?
    private let contentMode: ContentMode
    @Environment(\.imageLoader) private var loader
    @State private var image: UIImage?
    @State private var failed = false

    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    public var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.brewlyCrema)
                    .overlay {
                        Image(systemName: failed ? "photo" : "cup.and.saucer")
                            .foregroundStyle(Color.brewlyEspresso.opacity(0.4))
                    }
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url, let loader else { return }
        do {
            let data = try await loader.imageData(for: url)
            image = UIImage(data: data)
            failed = image == nil
        } catch {
            failed = true
        }
    }
}

/// A photo that keeps its aspect ratio (limited to portrait 4:5 and landscape 1.91:1) and fills it.
public struct PhotoView: View {
    private let media: MediaItem

    public init(media: MediaItem) {
        self.media = media
    }

    public var body: some View {
        Color.clear
            .aspectRatio(CGFloat(min(max(media.aspectRatio, 0.8), 1.91)), contentMode: .fit)
            .overlay { RemoteImage(url: media.url) }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
