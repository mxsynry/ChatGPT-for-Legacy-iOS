import UIKit
import ImageIO

// Restrict memory and storage pressure on older devices (iPhone 8 Plus).
// Preparation happens before the base64 attachment enters conversation storage.
enum ImagePreparation {
    static let maxSourceBytes = 40_000_000
    static let maxEncodedBytes = 2_000_000

    /// Full-size image bytes are never materialized as a UIImage on the UI
    /// thread; ImageIO first decodes a <=1536px thumbnail on a worker.
    static func jpeg(fromEncodedImageData data: Data) -> Data? {
        guard data.count <= maxSourceBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1536,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return jpeg(from: UIImage(cgImage: cg))
    }

    static func jpeg(from image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let maxEdge = max(image.size.width, image.size.height)
        let scale = min(1.0, 1536.0 / maxEdge)
        let targetSize = CGSize(width: max(1, (image.size.width * scale).rounded()),
                                height: max(1, (image.size.height * scale).rounded()))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        for quality: CGFloat in [0.72, 0.55, 0.38] {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= maxEncodedBytes {
                return data
            }
        }
        return nil
    }
}
