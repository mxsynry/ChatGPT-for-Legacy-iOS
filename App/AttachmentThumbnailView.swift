import SwiftUI
import ImageIO
import UIKit

/// Stage 21: decode attached images off the main actor at display resolution.
/// V20 rebuilt UIImage(data:) for every SwiftUI body evaluation during SSE.
/// This view retains only a small thumbnail, never the full-resolution bitmap.
struct AttachmentThumbnailView: View {
    let messageID: UUID
    let dataURL: String
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Attached photo")
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 180, height: 110)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Loading attached photo")
            }
        }
        .onDisappear {
            // Lazy stacks may retain @State for distant rows; discard our
            // strong UIImage reference when that row leaves the viewport.
            thumbnail = nil
        }
        .task(id: messageID) {
            let key = messageID.uuidString as NSString
            if let cached = ThumbnailCache.shared.object(forKey: key) {
                thumbnail = cached
                return
            }
            let source = dataURL
            let result = await Task.detached(priority: .utility) {
                ThumbnailDecoder.decode(source)
            }.value
            guard !Task.isCancelled else { return }
            if let result = result {
                ThumbnailCache.shared.setObject(result, forKey: key, cost: result.cgImage.map {
                    $0.bytesPerRow * $0.height
                } ?? 500_000)
            }
            thumbnail = result
        }
    }
}

/// Strict bounds also prevent malformed imported JSON from allocating enormous
/// base64 strings or full-sized bitmaps in the chat renderer.
enum ThumbnailDecoder {
    static let maxEncodedCharacters = 3_500_000
    static let maxPixelEdge = 520

    static func decode(_ source: String) -> UIImage? {
        // Keep the base64 payload as a String; Foundation's Data initializer
        // does not consistently resolve a Substring across Apple SDKs.
        let fields = source.split(separator: ",", maxSplits: 1,
                                  omittingEmptySubsequences: false)
        guard source.count <= maxEncodedCharacters,
              source.hasPrefix("data:image/"),
              fields.count == 2,
              let imageBytes = Data(base64Encoded: String(fields[1]),
                                    options: .ignoreUnknownCharacters),
              imageBytes.count <= 2_600_000,
              let dataSource = CGImageSourceCreateWithData(imageBytes as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelEdge,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(dataSource, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Only decoded, display-size images are cached; never raw image payloads.
final class ThumbnailCache {
    static let shared = NSCache<NSString, UIImage>()
    static func configure() {
        shared.countLimit = 48
        shared.totalCostLimit = 24 * 1024 * 1024
    }
    static func clear() { shared.removeAllObjects() }
}
