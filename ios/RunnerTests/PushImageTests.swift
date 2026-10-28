import CoreGraphics
import Foundation
import XCTest

#if canImport(PrismNotificationCore)
@testable import PrismNotificationCore
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Serves canned responses, or never answers when `body` is nil.
final class StubProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var status = 200
  nonisolated(unsafe) static var body: Data?
  nonisolated(unsafe) static var contentLength: String?
  nonisolated(unsafe) static var bytesSent = 0
  nonisolated(unsafe) static var sendsBody = true
  nonisolated(unsafe) static var stopCount = 0
  nonisolated(unsafe) static var requestCount = 0

  override class func canInit(with request: URLRequest) -> Bool {
    Self.requestCount += 1
    return true
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    guard let body = Self.body else { return }
    var headers: [String: String] = [:]
    if let contentLength = Self.contentLength { headers["Content-Length"] = contentLength }
    let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if Self.sendsBody {
      Self.bytesSent += body.count
      client?.urlProtocol(self, didLoad: body)
      client?.urlProtocolDidFinishLoading(self)
    } else {
      client?.urlProtocolDidFinishLoading(self)
    }
  }
  override func stopLoading() { Self.stopCount += 1 }
}

final class PushImageTests: XCTestCase {
  private let url = URL(string: "https://img.prismwalls.com/push-gallery/v1/\(String(repeating: "a", count: 64)).jpg")!

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
      "imageUrl": "https://img.prismwalls.com/previews/\(String(repeating: "b", count: 64)).img",
    ])
    XCTAssertEqual(gallery?.url, url)
    XCTAssertEqual(gallery?.clip, GalleryLayout.clippingRect(index: 2, count: 4))

    let previewURL = "https://img.prismwalls.com/previews/\(String(repeating: "b", count: 64)).img"
    let single = PushImageRequest(userInfo: ["imageUrl": previewURL])
    XCTAssertEqual(single?.url.absoluteString, previewURL)
    XCTAssertNil(single?.clip)

    let badGallery = PushImageRequest(userInfo: [
      "gallery_url": url.absoluteString, "gallery_count": "9", "gallery_thumb_index": "0", "imageUrl": "https://x.example/a.jpg",
    ])
    XCTAssertNil(badGallery, "an unsafe legacy URL is not fetched as a fallback")
    XCTAssertNil(PushImageRequest(userInfo: ["imageUrl": "http://img.example.com/a.jpg"]), "only https is fetched")
    XCTAssertNil(PushImageRequest(userInfo: ["imageUrl": "https://attacker.example/previews/\(String(repeating: "a", count: 64)).img"]))
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

  func testDownloadRejectsAnUnapprovedHostBeforeNetworking() async {
    StubProtocol.requestCount = 0
    StubProtocol.body = jpeg(width: 120, height: 55)
    let unsafeURL = URL(string: "https://attacker.example/previews/\(String(repeating: "a", count: 64)).img")!

    do {
      _ = try await PushImage.download(unsafeURL, session: session(), timeout: 5)
      XCTFail("expected an unapproved image host to be rejected")
    } catch {
      XCTAssertEqual(error as? PushImageError, .badResponse)
    }
    XCTAssertEqual(StubProtocol.requestCount, 0)
  }

  func testDownloadStopsAtTheTimeLimit() async {
    StubProtocol.body = nil
    StubProtocol.stopCount = 0
    let started = Date()
    do {
      _ = try await PushImage.download(url, session: session(), timeout: 0.3)
      XCTFail("expected a timeout")
    } catch {
      XCTAssertEqual(error as? PushImageError, .timedOut)
    }
    XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    XCTAssertGreaterThan(StubProtocol.stopCount, 0, "timing out cancels the active URLSession request")
  }

  #if canImport(UserNotifications)
  func testNotificationDeliveryInvokesCallbackOnce() {
    let content = UNMutableNotificationContent()
    content.body = "Text fallback"
    var calls = 0
    let delivery = NotificationDelivery(content: content) { delivered in
      calls += 1
      XCTAssertEqual(delivered.body, "Text fallback")
    }

    DispatchQueue.concurrentPerform(iterations: 32) { _ in
      delivery.finish(attachment: nil)
    }

    XCTAssertEqual(calls, 1)
    XCTAssertTrue(delivery.isFinished)
  }

  func testNotificationSessionRejectsRedirects() {
    let session = URLSession.shared
    let task = session.dataTask(with: url)
    let redirect = URLRequest(url: URL(string: "https://attacker.example/redirect")!)
    let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)!
    var followedRequest: URLRequest?

    NoRedirectDelegate().urlSession(
      session,
      task: task,
      willPerformHTTPRedirection: response,
      newRequest: redirect
    ) { followedRequest = $0 }

    XCTAssertNil(followedRequest)
  }
  #endif

  func testDeclaredOversizeResponseIsRejectedBeforeReadingBody() async {
    StubProtocol.status = 200
    StubProtocol.body = jpeg(width: 120, height: 55)
    StubProtocol.contentLength = "5242881"
    defer {
      StubProtocol.contentLength = nil
    }

    do {
      _ = try await PushImage.download(url, session: session(), timeout: 5)
      XCTFail("expected an oversized response to be rejected")
    } catch {
      XCTAssertEqual(error as? PushImageError, .tooLarge)
    }
  }

  func testUnknownLengthResponseIsRejectedWhenStreamExceedsByteLimit() async {
    StubProtocol.status = 200
    StubProtocol.contentLength = nil
    StubProtocol.body = Data(repeating: 0, count: 5 * 1024 * 1024 + 1)

    do {
      _ = try await PushImage.download(url, session: session(), timeout: 5)
      XCTFail("expected an unknown-length response over the byte limit to be rejected")
    } catch {
      XCTAssertEqual(error as? PushImageError, .tooLarge)
    }
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

    StubProtocol.body = jpeg(width: 2000, height: 1500)
    do {
      _ = try await PushImage.download(url, session: session(), timeout: 5)
      XCTFail("expected a high decoded pixel count to be rejected")
    } catch {
      XCTAssertEqual(error as? PushImageError, .notAnImage, "attachment decoding stays within the extension memory budget")
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
