import Foundation

private final class MediaRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, MediaRules.canDownload(url) else {
            completionHandler(nil)
            return
        }
        var clean = request
        clean.setValue(nil, forHTTPHeaderField: "Cookie")
        clean.setValue(nil, forHTTPHeaderField: "Authorization")
        completionHandler(clean)
    }
}

enum MediaDownloader {
    static func fetch(_ candidate: ImageCandidate) async throws -> Data {
        if let data = candidate.inlineData {
            guard data.count <= MediaRules.maxBytes else { throw PocketError.tooLarge }
            return data
        }
        guard let url = candidate.remoteURL else { throw PocketError.restrictedMedia }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration, delegate: MediaRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let finalURL = http.url, MediaRules.canDownload(finalURL) else { throw PocketError.restrictedMedia }
        if response.expectedContentLength > Int64(MediaRules.maxBytes) { throw PocketError.tooLarge }
        guard response.mimeType?.hasPrefix("image/") == true else { throw PocketError.noMedia }
        var data = Data()
        data.reserveCapacity(Int(max(0, min(response.expectedContentLength, Int64(MediaRules.maxBytes)))))
        for try await byte in bytes {
            if data.count >= MediaRules.maxBytes { throw PocketError.tooLarge }
            data.append(byte)
        }
        try Task.checkCancellation()
        guard !data.isEmpty else { throw PocketError.noMedia }
        return data
    }
}
