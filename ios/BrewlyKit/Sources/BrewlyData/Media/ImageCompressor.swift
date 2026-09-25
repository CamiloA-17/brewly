import Foundation
import UIKit

/// Prepares picked photos for upload: at most 1600 px on the longest side, JPEG.
enum ImageCompressor {
    static let maxDimension: CGFloat = 1600
    static let quality: CGFloat = 0.8

    /// `nil` when the data is not an image UIKit can read (JPEG, HEIC, PNG…).
    static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
