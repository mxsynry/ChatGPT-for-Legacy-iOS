import Foundation

@main struct RenderBenchmarkMain {
    static func main() {
        let value = Array(repeating: "Text **bold** with [link](https://example.com)\n```swift\nprint(42)\n```",
                          count: 55).joined(separator: "\n")
        let count = 1200
        let started = Date()
        var total = 0
        for _ in 0..<count { total += MarkdownSegments.split(value).count }
        let uncached = Date().timeIntervalSince(started)
        MarkdownRenderCache.clear()
        let cachedStarted = Date()
        for _ in 0..<count { total += MarkdownRenderCache.split(value).count }
        let cached = Date().timeIntervalSince(cachedStarted)
        print(String(format: "MARKDOWN BENCH (host Swift, not iPhone UI): %d parses, uncached %.3fs, cached %.3fs, checksummed segments %d", count, uncached, cached, total))
    }
}
