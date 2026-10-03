import ImageIO
import UIKit

/// Loads post thumbnails and blog icons from Explore's own image endpoints.
/// Images are downsampled to the size they are shown at and kept in memory,
/// so cells that scroll back into view draw at once.
final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private var failures: [String: Date] = [:]

    private init() {
        memory.totalCostLimit = 96 << 20
    }

    func cached(_ url: URL, pixels: CGFloat) -> UIImage? {
        memory.object(forKey: Self.key(url, pixels) as NSString)
    }

    /// True when the image failed recently; failures are retried after a
    /// few minutes, since Explore fetches images from the source on demand.
    func hasFailed(_ url: URL) -> Bool {
        guard let at = failures[url.absoluteString] else { return false }
        return Date.now.timeIntervalSince(at) < 300
    }

    func load(_ url: URL, pixels: CGFloat) async -> UIImage? {
        let key = Self.key(url, pixels)
        if let image = memory.object(forKey: key as NSString) { return image }
        if let task = inflight[key] { return await task.value }
        let task = Task { await ImageLoader.fetch(url, maxPixelSize: pixels) }
        inflight[key] = task
        let image = await task.value
        inflight[key] = nil
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            memory.setObject(image, forKey: key as NSString, cost: cost)
            failures[url.absoluteString] = nil
        } else {
            failures[url.absoluteString] = .now
        }
        return image
    }

    private static func key(_ url: URL, _ pixels: CGFloat) -> String {
        "\(url.absoluteString)#\(Int(pixels))"
    }
}

nonisolated enum ImageLoader {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 160 << 20)
        // Images change rarely; reuse what is on disk instead of asking
        // Explore again every minute.
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    @concurrent
    static func fetch(_ url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { return nil }
        return downsample(data, maxPixelSize: maxPixelSize)
    }

    /// Decodes at most maxPixelSize on the long edge. For icon files with
    /// several sizes the largest one is used.
    static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        var best = 0
        var bestWidth = 0
        for index in 0..<CGImageSourceGetCount(source) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            if width > bestWidth {
                best = index
                bestWidth = width
            }
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, best, options) else { return nil }
        return UIImage(cgImage: image)
    }
}
