import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit
import Combine

struct ImageInspection {
    let ext: String
    let mime: String
    let width: Int
    let height: Int
    let animated: Bool
    let thumbnail: Data
}

enum ImageInspector {
    static func inspect(_ data: Data) throws -> ImageInspection {
        guard !data.isEmpty else { throw PocketError.invalidImage }
        guard data.count <= MediaRules.maxBytes else { throw PocketError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier), type.conforms(to: .image),
              let ext = type.preferredFilenameExtension,
              let mime = type.preferredMIMEType,
              ["png", "jpeg", "jpg", "gif", "webp", "heic", "heif"].contains(ext.lowercased()),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw PocketError.invalidImage }
        guard width <= MediaRules.maxPixels / height else { throw PocketError.tooManyPixels }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 400,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let thumbnail = UIImage(cgImage: cg).pngData() else { throw PocketError.invalidImage }
        // ImageIO may report one frame for animated WebP on some OS versions.
        // RIFF animation flags supplement the frame count; the original is never re-encoded.
        let webPAnimated = data.count > 20 &&
            data.prefix(4) == Data("RIFF".utf8) &&
            data[8..<12] == Data("WEBP".utf8) &&
            data[12..<16] == Data("VP8X".utf8) &&
            (data[20] & 0x02) != 0
        return ImageInspection(ext: ext, mime: mime, width: width, height: height,
                               animated: CGImageSourceGetCount(source) > 1 || webPAnimated,
                               thumbnail: thumbnail)
    }
}

@MainActor
final class StickerStore: ObservableObject {
    @Published private(set) var stickers: [Sticker] = []
    @Published private(set) var loadError: String?
    private let root: URL
    private var writable = false
    private let thumbnails = NSCache<NSString, UIImage>()
    private var indexURL: URL { root.appendingPathComponent("collection.json") }

    init(directory: URL? = nil) {
        root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory,
                                                    in: .userDomainMask)[0]
            .appendingPathComponent("StickPocket", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var excluded = root
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                let decoded = try JSONDecoder().decode([Sticker].self, from: Data(contentsOf: indexURL))
                guard decoded.allSatisfy({
                    $0.filename == ($0.filename as NSString).lastPathComponent &&
                    $0.thumbnailFilename == ($0.thumbnailFilename as NSString).lastPathComponent &&
                    !$0.filename.isEmpty && !$0.thumbnailFilename.isEmpty &&
                    !$0.filename.hasPrefix(".") && !$0.thumbnailFilename.hasPrefix(".")
                }) else { throw PocketError.unavailableStorage }
                stickers = decoded
            }
            writable = true
        } catch {
            loadError = PocketError.unavailableStorage.localizedDescription
            // Never silently reset a corrupt index or overwrite the existing collection.
        }
        thumbnails.countLimit = 80
    }

    func fileURL(for sticker: Sticker) -> URL { root.appendingPathComponent(sticker.filename) }

    func data(for sticker: Sticker) throws -> Data {
        try Data(contentsOf: fileURL(for: sticker), options: .mappedIfSafe)
    }

    func thumbnail(for sticker: Sticker) -> UIImage? {
        let key = sticker.id.uuidString as NSString
        if let image = thumbnails.object(forKey: key) { return image }
        let image = UIImage(contentsOfFile: root.appendingPathComponent(sticker.thumbnailFilename).path)
        if let image { thumbnails.setObject(image, forKey: key) }
        return image
    }

    @discardableResult
    func add(data: Data, name: String, origin: StickerOrigin) throws -> (sticker: Sticker, duplicate: Bool) {
        guard writable else { throw PocketError.unavailableStorage }
        guard !data.isEmpty else { throw PocketError.invalidImage }
        guard data.count <= MediaRules.maxBytes else { throw PocketError.tooLarge }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let existing = stickers.first(where: { $0.digest == digest }) { return (existing, true) }
        let info = try ImageInspector.inspect(data)
        let id = UUID()
        let item = Sticker(id: id, name: cleanName(name), filename: "\(id).\(info.ext)",
                           thumbnailFilename: "\(id)-thumb.png", digest: digest, mime: info.mime,
                           width: info.width, height: info.height, isAnimated: info.animated,
                           byteCount: data.count, origin: origin, createdAt: Date(), favorite: false)
        let original = fileURL(for: item)
        let thumb = root.appendingPathComponent(item.thumbnailFilename)
        do {
            try data.write(to: original, options: [.atomic, .completeFileProtection])
            try info.thumbnail.write(to: thumb, options: [.atomic, .completeFileProtection])
            var next = stickers
            next.insert(item, at: 0)
            try persist(next)
            stickers = next
        } catch {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: thumb)
            throw error
        }
        return (item, false)
    }

    func rename(_ item: Sticker, to name: String) throws {
        var next = stickers
        guard let index = next.firstIndex(where: { $0.id == item.id }) else { return }
        next[index].name = cleanName(name)
        try persist(next)
        stickers = next
    }

    func toggleFavorite(_ item: Sticker) throws {
        var next = stickers
        guard let index = next.firstIndex(where: { $0.id == item.id }) else { return }
        next[index].favorite.toggle()
        try persist(next)
        stickers = next
    }

    func remove(_ item: Sticker) throws {
        // Commit the index first. Interrupted deletion leaves only an unreferenced file,
        // never an index pointing to files removed by this operation.
        let next = stickers.filter { $0.id != item.id }
        try persist(next)
        stickers = next
        thumbnails.removeObject(forKey: item.id.uuidString as NSString)
        try? FileManager.default.removeItem(at: fileURL(for: item))
        try? FileManager.default.removeItem(at: root.appendingPathComponent(item.thumbnailFilename))
    }

    private func cleanName(_ value: String) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Il mio sticker" : String(value.prefix(80))
    }

    private func persist(_ next: [Sticker]) throws {
        guard writable else { throw PocketError.unavailableStorage }
        let bytes = try JSONEncoder().encode(next)
        try bytes.write(to: indexURL, options: [.atomic, .completeFileProtection])
    }
}
