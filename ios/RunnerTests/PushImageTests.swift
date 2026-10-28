import CoreGraphics
import Foundation
import XCTest

#if canImport(PrismNotificationCore)
@testable import PrismNotificationCore
#endif

/// Serves canned responses, or never answers when `body` is nil.
final class StubProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var status = 200
  nonisolated(unsafe) static var body: Data?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    guard let body = Self.body else { return }
    let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: body)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

final class PushImageTests: XCTestCase {
  private let url = URL(string: "https://img.example.com/push-gallery/v1/a.jpg")!

  private func session() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubProtocol.self]
    return URLSession(configuration: config)
  }

  private func jpeg(width: Int, height: Int) -> Data {
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, context.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
  }

  func testClippingRectMatchesTheServerStripLayout() {
    XCTAssertEqual(
      GalleryLayout.clippingRect(index: 0, count: 4), CGRect(x: 16.0 / 1200, y: 16.0 / 545, width: 283.0 / 1200, height: 513.0 / 545))
    XCTAssertEqual(GalleryLayout.clippingRect(index: 3, count: 4)!.minX, 901.0 / 1200, accuracy: 1e-9)
    XCTAssertEqual(GalleryLayout.clippingRect(index: 1, count: 3)!.minX, 458.5 / 1200, accuracy: 1e-9)
    XCTAssertEqual(GalleryLayout.clippingRect(index: 1, count: 2)!.minX, 606.0 / 1200, accuracy: 1e-9)
    XCTAssertNil(GalleryLayout.clippingRect(index: 4, count: 4))
    XCTAssertNil(GalleryLayout.clippingRect(index: -1, count: 4))
    XCTAssertNil(GalleryLayout.clippingRect(index: 0, count: 5))
    XCTAssertNil(GalleryLayout.clippingRect(index: 0, count: 1))
  }

  func testGalleryPushClipsToTheLeadWallAndSinglePushAttachesWhole() {
    let gallery = PushImageRequest(userInfo: [
      "gallery_url": url.absoluteString, "gallery_count": "4", "gallery_thumb_index": "2",
      "imageUrl": "https://img.example.com/previews/w1.img",
    ])
    XCTAssertEqual(gallery?.url, url)
    XCTAssertEqual(gallery?.clip, GalleryLayout.clippingRect(index: 2, count: 4))

    let single = PushImageRequest(userInfo: ["imageUrl": "https://img.example.com/previews/w1.img"])
    XCTAssertEqual(single?.url.absoluteString, "https://img.example.com/previews/w1.img")
    XCTAssertNil(single?.clip)

    let badGallery = PushImageRequest(userInfo: [
      "gallery_url": url.absoluteString, "gallery_count": "9", "gallery_thumb_index": "0", "imageUrl": "https://x.example/a.jpg",
    ])
    XCTAssertEqual(badGallery?.url.absoluteString, "https://x.example/a.jpg", "a bad gallery falls back to the single image")
    XCTAssertNil(PushImageRequest(userInfo: ["imageUrl": "http://img.example.com/a.jpg"]), "only https is fetched")
    XCTAssertNil(PushImageRequest(userInfo: [:]))
  }

  func testDownloadReturnsAJpegFileForAnAttachment() async throws {
    StubProtocol.status = 200
    StubProtocol.body = jpeg(width: 120, height: 55)
    let file = try await PushImage.download(url, session: session(), timeout: 5)
    defer { try? FileManager.default.removeItem(at: file) }
    XCTAssertEqual(file.pathExtension, "jpg")
    XCTAssertEqual(try Data(contentsOf: file), StubProtocol.body)
  }

  func testDownloadStopsAtTheTimeLimit() async {
    StubProtocol.body = nil
    let started = Date()
    do {
      _ = try await PushImage.download(url, session: session(), timeout: 0.3)
      XCTFail("expected a timeout")
    } catch {
      XCTAssertEqual(error as? PushImageError, .timedOut)
    }
    XCTAssertLessThan(Date().timeIntervalSince(started), 2)
  }

  func testBadImageBytesAndErrorsAreRejected() async {
    StubProtocol.status = 200
    StubProtocol.body = Data("<html>not an image</html>".utf8)
    do {
      _ = try await PushImage.download(url, session: session(), timeout: 5)
      XCTFail("expected a rejection")
    } catch {
      XCTAssertEqual(error as? PushImageError, .notAnImage)
    }

    StubProtocol.body = jpeg(width: 5000, height: 10)
    do {
      _ = try await PushImage.download(url, session: session(), timeout: 5)
      XCTFail("expected a rejection")
    } catch {
      XCTAssertEqual(error as? PushImageError, .notAnImage, "an oversized image is never decoded")
    }

    StubProtocol.status = 404
    StubProtocol.body = jpeg(width: 10, height: 10)
    do {
      _ = try await PushImage.download(url, session: session(), timeout: 5)
      XCTFail("expected a rejection")
    } catch {
      XCTAssertEqual(error as? PushImageError, .badResponse)
    }
  }
}
