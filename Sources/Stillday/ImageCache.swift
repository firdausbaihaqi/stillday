import AppKit
import ImageIO

/// One worker for large previews and one for thumbnails cap concurrent full-image decodes.
private actor ImageDecoder {
    func decode(path: String, pixels: Int) -> (CGImage, Bool)? {
        guard !Task.isCancelled,
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels
              ] as CFDictionary) else { return nil }
        return Task.isCancelled ? nil : (image, Thread.isMainThread)
    }
}

@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()
    private let previews = ImageDecoder()
    private let thumbnails = ImageDecoder()
    private var pending: [String: Task<(CGImage, Bool)?, Never>] = [:]
    private var generation = 0
    private(set) var mainThreadDecodes = 0

    init() { cache.totalCostLimit = 24 * 1024 * 1024; cache.countLimit = 60 }

    func contains(path: String, pixels: Int) -> Bool { cache.object(forKey: key(path, pixels) as NSString) != nil }

    func image(path: String, pixels: Int) async -> NSImage? {
        let key = key(path, pixels)
        if let image = cache.object(forKey: key as NSString) { return image }
        let requestGeneration = generation
        let task: Task<(CGImage, Bool)?, Never>
        if let existing = pending[key] { task = existing }
        else {
            let worker = pixels > 600 ? previews : thumbnails
            task = Task.detached(priority: .userInitiated) { await worker.decode(path: path, pixels: pixels) }
            pending[key] = task
        }
        let decoded = await task.value
        guard generation == requestGeneration else { return nil }
        pending[key] = nil
        if let image = cache.object(forKey: key as NSString) { return image }
        guard let (cgImage, decodedOnMain) = decoded else { return nil }
        if decodedOnMain { mainThreadDecodes += 1 }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key as NSString, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    func clear() {
        generation += 1
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        cache.removeAllObjects()
    }
    private func key(_ path: String, _ pixels: Int) -> String { "\(path)|\(pixels)" }
}
