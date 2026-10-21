import XCTest
import UIKit
@testable import StickPocket

final class StickPocketTests: XCTestCase {
    func testOnlyRealTikTokHTTPSLinksAreAccepted() {
        XCTAssertTrue(MediaRules.isTikTok(URL(string: "https://www.tiktok.com/@example/video/1")!))
        XCTAssertTrue(MediaRules.isTikTok(URL(string: "https://vm.tiktok.com/short")!))
        for value in [
            "http://www.tiktok.com", "https://tiktok.com.evil.invalid/a",
            "https://eviltiktok.com/a", "https://user@tiktok.com/a",
            "https://tiktok.com:8443/a", "file:///tmp/image.png"
        ] {
            XCTAssertFalse(MediaRules.isTikTok(URL(string: value)!), value)
        }
    }

    func testMediaDownloadsNeverAcceptPrivateOrArbitraryDestinations() {
        XCTAssertTrue(MediaRules.canDownload(URL(string: "https://p16.tiktokcdn.com/image.gif?token=example")!))
        for value in [
            "https://127.0.0.1/image", "http://p16.tiktokcdn.com/image",
            "https://tiktokcdn.com.evil.invalid/image", "https://example.com/image",
            "https://user:password@tiktokcdn.com/image", "file:///etc/passwd"
        ] {
            XCTAssertFalse(MediaRules.canDownload(URL(string: value)!), value)
        }
    }

    func testSharedCaptionExtractsOnlyTikTokLink() {
        XCTAssertEqual(MediaRules.videoURL(from: "Guarda questo! https://vm.tiktok.com/abc")?.host, "vm.tiktok.com")
        XCTAssertNil(MediaRules.videoURL(from: "https://example.com/?next=https://tiktok.com"))
    }

    func testCropClampsReverseDragToImageBounds() {
        let selection = CropMath.selection(start: CGPoint(x: 120, y: 250),
                                           end: CGPoint(x: -20, y: -10),
                                           size: CGSize(width: 100, height: 200))
        XCTAssertEqual(selection, CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(CropMath.pixels(selection, width: 300, height: 600),
                       CGRect(x: 0, y: 0, width: 300, height: 600))
        XCTAssertEqual(CropMath.selection(start: .zero, end: .zero, size: .zero), .zero)
    }

    @MainActor
    func testOriginalBytesDuplicatesAndFavoritesSurviveReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StickerStore(directory: root)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "animated", withExtension: "gif"))
        let bytes = try Data(contentsOf: fixture)
        let first = try store.add(data: bytes, name: "Ciao", origin: .messages)
        XCTAssertFalse(first.duplicate)
        XCTAssertTrue(first.sticker.isAnimated)
        XCTAssertEqual(try store.data(for: first.sticker), bytes)
        let duplicate = try store.add(data: bytes, name: "Altro", origin: .comments)
        XCTAssertTrue(duplicate.duplicate)
        XCTAssertEqual(store.stickers.count, 1)
        try store.toggleFavorite(first.sticker)
        try store.rename(first.sticker, to: "Il preferito")
        let restored = StickerStore(directory: root)
        XCTAssertEqual(restored.stickers.count, 1)
        XCTAssertTrue(try XCTUnwrap(restored.stickers.first).favorite)
        XCTAssertEqual(restored.stickers.first?.name, "Il preferito")
        XCTAssertEqual(try restored.data(for: first.sticker), bytes)
        try restored.remove(first.sticker)
        XCTAssertTrue(StickerStore(directory: root).stickers.isEmpty)
    }

    @MainActor
    func testCorruptIndexIsPreservedAndWritesFail() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let broken = Data("{broken".utf8)
        let path = root.appendingPathComponent("collection.json")
        try broken.write(to: path)
        let store = StickerStore(directory: root)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.add(data: Data(), name: "Test", origin: .files))
        XCTAssertEqual(try Data(contentsOf: path), broken)
    }

    func testRejectsHTMLAndOversizedInputs() {
        XCTAssertThrowsError(try ImageInspector.inspect(Data("<html>login</html>".utf8)))
        XCTAssertThrowsError(try ImageInspector.inspect(Data(repeating: 0, count: MediaRules.maxBytes + 1)))
    }
}
