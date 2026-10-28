import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The gallery image the server renders: one row of portrait walls on a 1200 x 545 canvas
/// (`functions/src/pushGallery.ts`, `galleryRects("strip", count)`).
public enum GalleryLayout {
  static let width: CGFloat = 1200
  static let height: CGFloat = 545
  static let pad: CGFloat = 16
  static let gap: CGFloat = 12
  static let tileWidth: CGFloat = 283

  /// The unit-space rect of wall `index` in a gallery of `count` walls, so the collapsed thumbnail is that one wall.
  public static func clippingRect(index: Int, count: Int) -> CGRect? {
    guard (2...4).contains(count), (0..<count).contains(index) else { return nil }
    let row = CGFloat(count) * tileWidth + CGFloat(count - 1) * gap
    let x = (width - row) / 2 + CGFloat(index) * (tileWidth + gap)
    return CGRect(x: x / width, y: pad / height, width: tileWidth / width, height: (height - 2 * pad) / height)
  }
}

/// The image a push asks the service extension to attach.
public struct PushImageRequest: Equatable, Sendable {
  public let url: URL
  /// Set for a gallery: the lead wall, used as the collapsed thumbnail.
  public let clip: CGRect?

  /// A gallery push carries `gallery_url`, `gallery_count` and `gallery_thumb_index`. Any other push with an
  /// `imageUrl` attaches that image whole. Only https URLs are fetched.
  public init?(userInfo: [AnyHashable: Any]) {
    func string(_ key: String) -> String? { (userInfo[key] as? String)?.trimmingCharacters(in: .whitespaces) }
    if let gallery = string("gallery_url").flatMap(URL.init(string:)), gallery.scheme == "https",
      let count = string("gallery_count").flatMap(Int.init),
      let index = string("gallery_thumb_index").flatMap(Int.init),
      let clip = GalleryLayout.clippingRect(index: index, count: count)
    {
      url = gallery
      self.clip = clip
      return
    }
    guard let single = string("imageUrl").flatMap(URL.init(string:)), single.scheme == "https" else { return nil }
    url = single
    clip = nil
  }
}

public enum PushImageError: Error, Equatable {
  case timedOut
  case badResponse
  case tooLarge
  case notAnImage
}

public enum PushImage {
  /// The system gives the extension about 30 seconds. The download stops well before that, so the text push still
  /// arrives on time.
  public static let timeout: TimeInterval = 20
  static let maxBytes = 5 * 1024 * 1024
  static let maxPixels = 4096

  /// Downloads the image, checks that it is a small decodable JPEG, PNG or HEIC, and returns a temporary file with the
  /// extension the attachment API needs.
  public static func download(_ url: URL, session: URLSession, timeout: TimeInterval = timeout) async throws -> URL {
    try await withThrowingTaskGroup(of: URL.self) { group in
      group.addTask { try await fetch(url, session: session) }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        throw PushImageError.timedOut
      }
      defer { group.cancelAll() }
      guard let file = try await group.next() else { throw PushImageError.timedOut }
      return file
    }
  }

  private static func fetch(_ url: URL, session: URLSession) async throws -> URL {
    let (downloaded, response) = try await session.download(from: url)
    defer { try? FileManager.default.removeItem(at: downloaded) }
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw PushImageError.badResponse
    }
    let size = (try? FileManager.default.attributesOfItem(atPath: downloaded.path)[.size] as? Int) ?? 0
    guard size > 0, size <= maxBytes else { throw PushImageError.tooLarge }
    let ext = try imageExtension(of: downloaded)
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
    try FileManager.default.moveItem(at: downloaded, to: file)
    return file
  }

  /// Reads only the header, so a huge or broken image never decodes in the extension's small memory budget.
  static func imageExtension(of file: URL) throws -> String {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
      let type = CGImageSourceGetType(source).map({ UTType($0 as String) }) ?? nil,
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
      w > 0, h > 0, w <= maxPixels, h <= maxPixels
    else { throw PushImageError.notAnImage }
    if type.conforms(to: .jpeg) { return "jpg" }
    if type.conforms(to: .png) { return "png" }
    if type.conforms(to: .heic) { return "heic" }
    throw PushImageError.notAnImage
  }
}
