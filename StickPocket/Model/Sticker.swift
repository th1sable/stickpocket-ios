import Foundation

enum StickerOrigin: String, Codable, CaseIterable {
    case comments, messages, photos, files, crop
    var label: String {
        switch self {
        case .comments: return "Commenti"
        case .messages: return "Messaggi"
        case .photos: return "Foto"
        case .files: return "File"
        case .crop: return "Ritaglio"
        }
    }
}

struct Sticker: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let filename: String
    let thumbnailFilename: String
    let digest: String
    let mime: String
    let width: Int
    let height: Int
    let isAnimated: Bool
    let byteCount: Int
    let origin: StickerOrigin
    let createdAt: Date
    var favorite: Bool
}

enum PocketError: LocalizedError {
    case invalidImage, tooLarge, tooManyPixels, unavailableStorage
    case unsupportedLink, restrictedMedia, noMedia, invalidCrop

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Questo file non è un’immagine supportata. Prova PNG, JPEG, GIF, WebP o HEIC."
        case .tooLarge: return "Il file supera 25 MB. Scegli un’immagine più piccola."
        case .tooManyPixels: return "L’immagine è troppo grande. Il limite è 32 milioni di pixel."
        case .unavailableStorage: return "Non riesco ad aprire la raccolta. I file esistenti non sono stati modificati."
        case .unsupportedLink: return "Incolla il link HTTPS di un video TikTok."
        case .restrictedMedia: return "TikTok non rende disponibile questo file. Puoi importare uno screenshot e ritagliarlo."
        case .noMedia: return "Non è arrivato un file immagine. Riapri la pagina e scegli di nuovo lo sticker."
        case .invalidCrop: return "Seleziona un’area più grande da ritagliare."
        }
    }
}

enum MediaRules {
    static let maxBytes = 25 * 1024 * 1024
    static let maxPixels = 32_000_000
    private static let mediaDomains = [
        "tiktok.com", "tiktokcdn.com", "tiktokcdn-us.com", "tiktokcdn-eu.com",
        "tiktokv.com", "byteoversea.com", "ibytedtos.com", "ibyteimg.com",
        "byteimg.com", "muscdn.com", "pstatp.com"
    ]

    static func matches(_ host: String, domain: String) -> Bool {
        let lower = host.lowercased()
        return lower == domain || lower.hasSuffix("." + domain)
    }

    static func isTikTok(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil,
              url.password == nil, url.port == nil || url.port == 443,
              let host = url.host else { return false }
        return matches(host, domain: "tiktok.com")
    }

    static func canDownload(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil,
              url.password == nil, url.port == nil || url.port == 443,
              let host = url.host else { return false }
        return mediaDomains.contains { matches(host, domain: $0) }
    }

    static func videoURL(from text: String) -> URL? {
        // Share text can contain a caption: use the first actual HTTPS link.
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let url = match.url, isTikTok(url) else { return nil }
        return url
    }
}
