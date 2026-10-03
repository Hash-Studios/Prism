import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

final class MediaFixture {
  let root: URL
  let source: URL
  let downloads: URL

  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent("PrismTests-\(UUID().uuidString)")
    source = root.appendingPathComponent("image with spaces.png")
    downloads = root.appendingPathComponent("downloads", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let context = try #require(CGContext(
      data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(
      source as CFURL, UTType.png.identifier as CFString, 1, nil
    ))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
  }

  deinit {
    try? FileManager.default.removeItem(at: root)
  }

  func downloader(status: Int = 200) -> @Sendable (URLRequest) async throws -> (URL, URLResponse) {
    let source = source
    let root = root
    return { request in
      let temporary = root.appendingPathComponent(UUID().uuidString)
      try FileManager.default.copyItem(at: source, to: temporary)
      let url = try #require(request.url)
      let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
      return (temporary, response)
    }
  }
}
