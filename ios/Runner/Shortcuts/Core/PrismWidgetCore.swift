import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

enum PrismWidgetKind {
  static let wallOfTheDay = "PrismWallOfTheDay"
  static let streak = "PrismStreak"
}

enum PrismWotdImageBudget {
  static let maximumPixels = 718_080
  /// The decode before the crop. A portrait wall in a wide widget needs its full width; a panorama stays bounded.
  static let maximumDecodePixels = 3_000_000

  static func boundedPixels(_ pixels: CGSize) -> CGSize {
    guard pixels.width > 0, pixels.height > 0 else { return CGSize(width: 0, height: 0) }
    let area = pixels.width * pixels.height
    guard area > CGFloat(maximumPixels) else { return pixels }
    let scale = sqrt(CGFloat(maximumPixels) / area)
    return CGSize(width: floor(pixels.width * scale), height: floor(pixels.height * scale))
  }

  static func thumbnailMaxPixelSize(source: CGSize, filling pixels: CGSize) -> Int {
    let fill = min(1, max(pixels.width / source.width, pixels.height / source.height))
    let area = min(1, sqrt(CGFloat(maximumDecodePixels) / (source.width * source.height)))
    let long = max(source.width, source.height)
    return max(1, Int(min(ceil(long * fill), floor(long * area))))
  }
}

enum PrismWotdBytes {
  static func read<Bytes: AsyncSequence>(_ bytes: Bytes, limit: Int) async throws -> Data where Bytes.Element == UInt8 {
    guard limit > 0 else { throw URLError(.dataLengthExceedsMaximum) }
    var data = Data()
    for try await byte in bytes {
      guard data.count < limit else { throw URLError(.dataLengthExceedsMaximum) }
      data.append(byte)
    }
    guard !data.isEmpty else { throw URLError(.badServerResponse) }
    return data
  }
}

actor PrismWotdRefreshCoordinator {
  typealias Result = (wall: PrismWotdWall?, pickedDay: String?)
  private var inFlight: Task<Result, Never>?

  func task(load: @escaping @Sendable () async -> Result) -> Task<Result, Never> {
    if let inFlight { return inFlight }
    let task = Task {
      let result = await load()
      inFlight = nil
      return result
    }
    inFlight = task
    return task
  }
}

#if canImport(ImageIO)
enum PrismWotdImage {
  static func decode(_ data: Data, filling pixels: CGSize) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return decode(source, filling: pixels)
  }

  static func decode(_ source: CGImageSource, filling pixels: CGSize) -> CGImage? {
    let pixels = PrismWotdImageBudget.boundedPixels(pixels)
    guard let thumbnail = thumbnail(source, filling: pixels) else { return nil }
    let width = CGFloat(thumbnail.width)
    let height = CGFloat(thumbnail.height)
    let fit = min(width / pixels.width, height / pixels.height)
    let crop = CGRect(
      x: floor((width - pixels.width * fit) / 2), y: floor((height - pixels.height * fit) / 2),
      width: max(1, floor(pixels.width * fit)), height: max(1, floor(pixels.height * fit))
    )
    return thumbnail.cropping(to: crop)
  }

  static func thumbnail(_ source: CGImageSource, filling pixels: CGSize) -> CGImage? {
    guard pixels.width > 0, pixels.height > 0, CGImageSourceGetStatus(source) == .statusComplete,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? CGFloat, width > 0,
      let height = properties[kCGImagePropertyPixelHeight] as? CGFloat, height > 0
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: PrismWotdImageBudget.thumbnailMaxPixelSize(
        source: CGSize(width: width, height: height), filling: pixels
      ),
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
      CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
    else { return nil }
    return thumbnail
  }
}
#endif

/// What the app writes for the streak widgets. The app owns the streak; the widget only reads this copy.
struct PrismStreakSnapshot: Codable, Equatable, Sendable {
  let count: Int
  /// The last kept day as yyyy-MM-dd in the streak's time zone.
  let lastKeptDay: String
  let utcOffsetMinutes: Int
  let freezes: Int
}

struct PrismStreakDisplay: Equatable, Sendable {
  let count: Int
  let keptToday: Bool
}

enum PrismStreakStore {
  static let appGroup = "group.com.hash.prism"
  static let key = "widget.streak"

  static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> PrismStreakSnapshot? {
    guard let data = defaults?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(PrismStreakSnapshot.self, from: data)
  }

  static func save(_ snapshot: PrismStreakSnapshot?, to defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) {
    guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
      defaults?.removeObject(forKey: key)
      return
    }
    defaults?.set(data, forKey: key)
  }
}

enum PrismStreakRule {
  /// Mirrors isStreakAlive in lib/core/coins/coin_policy.dart: the streak lives while the gap since the last kept
  /// day is at most one day plus the held freezes. Nil means signed out.
  static func display(_ snapshot: PrismStreakSnapshot?, at now: Date) -> PrismStreakDisplay? {
    guard let snapshot else { return nil }
    let today = dayKey(now, utcOffsetMinutes: snapshot.utcOffsetMinutes)
    guard snapshot.count > 0, let gap = dayGap(from: snapshot.lastKeptDay, to: today),
      gap <= 1 + max(0, snapshot.freezes)
    else { return PrismStreakDisplay(count: 0, keptToday: false) }
    return PrismStreakDisplay(count: snapshot.count, keptToday: gap == 0)
  }

  static func dayKey(_ date: Date, utcOffsetMinutes: Int) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: utcOffsetMinutes * 60) ?? utc
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  static func dayGap(from start: String, to end: String) -> Int? {
    guard let first = utcMidnight(start), let last = utcMidnight(end) else { return nil }
    return Int((last.timeIntervalSince(first) / 86_400).rounded())
  }

  /// The next local midnights in the streak's time zone, where the ring can change without the app.
  static func midnights(after now: Date, utcOffsetMinutes: Int, count: Int) -> [Date] {
    let offset = Double(utcOffsetMinutes * 60)
    let nextLocal = (floor((now.timeIntervalSince1970 + offset) / 86_400) + 1) * 86_400
    return (0..<count).map { Date(timeIntervalSince1970: nextLocal + Double($0) * 86_400 - offset) }
  }

  private static let utc = TimeZone(secondsFromGMT: 0)!

  private static func utcMidnight(_ key: String) -> Date? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard key.count == 10, parts.count == 3 else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
      dayKey(date, utcOffsetMinutes: 0) == key
    else { return nil }
    return date
  }
}

struct PrismWotdWall: Codable, Equatable, Sendable {
  let documentId: String
  /// Share links resolve walls by the `id` field, which is not the document id.
  let shareId: String
  let imageURL: URL
  let title: String?
  let creator: String?
  /// UTC yyyy-MM-dd of the pick, from wall_of_the_day/current.
  let pickedDay: String
}

struct PrismWotdCacheManifest: Codable, Equatable {
  let wall: PrismWotdWall
  let imageFileName: String

  func imageFile(in directory: URL, for expectedWall: PrismWotdWall) -> URL? {
    guard wall == expectedWall else { return nil }
    let file = directory.appendingPathComponent(imageFileName)
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }
}

struct PrismWotdDiskCache {
  let directory: URL
  private var manifestFile: URL { directory.appendingPathComponent("wall.json") }

  func load() -> PrismWotdCacheManifest? {
    guard let data = try? Data(contentsOf: manifestFile),
      let record = try? JSONDecoder().decode(PrismWotdCacheManifest.self, from: data),
      record.imageFile(in: directory, for: record.wall) != nil
    else { return nil }
    return record
  }

  func update(_ wall: PrismWotdWall, includeImage: Bool, image: () async throws -> Data) async throws {
    guard includeImage else { return }
    try save(wall, image: await image())
  }

  func save(
    _ wall: PrismWotdWall, image: Data,
    publish: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
  ) throws {
    #if canImport(ImageIO)
    guard PrismWotdImage.decode(image, filling: CGSize(width: 32, height: 32)) != nil else {
      throw URLError(.cannotDecodeContentData)
    }
    #endif
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let imageFile = directory.appendingPathComponent("image-\(UUID().uuidString)")
    try image.write(to: imageFile, options: .atomic)
    do {
      let record = PrismWotdCacheManifest(wall: wall, imageFileName: imageFile.lastPathComponent)
      try publish(JSONEncoder().encode(record), manifestFile)
    } catch {
      try? FileManager.default.removeItem(at: imageFile)
      throw error
    }
    let cutoff = Date().addingTimeInterval(-7 * 86_400)
    for file in (try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
    )) ?? [] where file.lastPathComponent.hasPrefix("image-") {
      if let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
        modified < cutoff
      {
        try? FileManager.default.removeItem(at: file)
      }
    }
  }
}

enum PrismWotdParser {
  /// Nil when the wall has no display image. The widget never falls back to the original: it is too large.
  static func wall(pointer: PrismShortcutWotdIdentity, document: Data) -> PrismWotdWall? {
    guard let thumb = field("wallpaper_thumb", document), let url = URL(string: thumb), url.scheme == "https",
      url.host?.isEmpty == false
    else { return nil }
    return PrismWotdWall(
      documentId: pointer.documentId,
      shareId: field("id", document) ?? pointer.documentId,
      imageURL: url,
      title: field("title", document),
      creator: field("by", document),
      pickedDay: pointer.day
    )
  }

  private static func field(_ name: String, _ document: Data) -> String? {
    let value = PrismFirestoreREST.stringField(name, in: document)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return value?.isEmpty == false ? value : nil
  }
}

enum PrismWotdSelection {
  static func resolve(pointer: PrismShortcutWotdIdentity, document: Data, cached: PrismWotdWall?)
    -> (wall: PrismWotdWall?, pickedDay: String?)
  {
    guard let wall = PrismWotdParser.wall(pointer: pointer, document: document) else { return (cached, nil) }
    return (wall, pointer.day)
  }
}

enum PrismWotdSchedule {
  /// functions/src/wallOfTheDay.ts picks a new wall every day at 03:30 UTC.
  static let rotationSecondOfDay: TimeInterval = 3 * 3_600 + 30 * 60
  /// Time for the pick and its retries to land before the widget asks.
  static let settle: TimeInterval = 10 * 60
  static let retry: TimeInterval = 30 * 60

  static func lastRotation(atOrBefore now: Date) -> Date {
    let today = floor(now.timeIntervalSince1970 / 86_400) * 86_400 + rotationSecondOfDay
    return Date(timeIntervalSince1970: today <= now.timeIntervalSince1970 ? today : today - 86_400)
  }

  /// After the next rotation. Sooner when the fetch failed or the server has not rotated yet, but never later.
  static func nextRefresh(after now: Date, pickedDay: String?) -> Date {
    let last = lastRotation(atOrBefore: now)
    let settleDeadline = last.addingTimeInterval(settle)
    let next = settleDeadline > now ? settleDeadline : last.addingTimeInterval(86_400 + settle)
    guard pickedDay == PrismShortcutWotdIdentity.utcDay(last) else { return min(now.addingTimeInterval(retry), next) }
    return next
  }
}

enum PrismWidgetLink {
  private static let unreserved = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~"
  )

  /// The share link the app already parses, plus the widget kind for analytics.
  static func wall(_ wall: PrismWotdWall, widget: String) -> URL? {
    url("share", [("id", wall.shareId), ("source", "prism"), ("thumb", wall.imageURL.absoluteString), ("widget", widget)])
  }

  static func streak(widget: String) -> URL? {
    url("streak", [("widget", widget)])
  }

  private static func url(_ host: String, _ query: [(String, String)]) -> URL? {
    let pairs = query.compactMap { name, value in
      value.addingPercentEncoding(withAllowedCharacters: unreserved).map { "\(name)=\($0)" }
    }
    return URL(string: "prism://\(host)?\(pairs.joined(separator: "&"))")
  }
}
