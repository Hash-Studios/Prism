import Foundation
import Testing
#if canImport(ImageIO)
import ImageIO
import UniformTypeIdentifiers
#endif

#if canImport(PrismShortcutsCore)
@testable import PrismShortcutsCore
#endif
#if canImport(Runner)
@testable import Runner
#endif

struct PrismWidgetCoreTests {
  private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
  }

  private func snapshot(count: Int = 12, day: String = "2026-10-27", offset: Int = 330, freezes: Int = 0)
    -> PrismStreakSnapshot
  {
    PrismStreakSnapshot(count: count, lastKeptDay: day, utcOffsetMinutes: offset, freezes: freezes)
  }

  // MARK: Timeline schedule

  @Test func refreshesAfterTomorrowsRotationOnceTodaysPickIsIn() {
    let now = date("2026-10-27T09:00:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: "2026-10-27") == date("2026-10-28T03:40:00Z"))
  }

  @Test func beforeTheRotationYesterdaysPickIsCurrent() {
    let now = date("2026-10-27T02:00:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: "2026-10-26") == date("2026-10-27T03:40:00Z"))
  }

  @Test func retriesSoonWhenTheServerHasNotRotatedYet() {
    let now = date("2026-10-27T03:35:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: "2026-10-26") == date("2026-10-27T03:40:00Z"))
  }

  @Test func retriesSoonWhenOffline() {
    let now = date("2026-10-27T12:00:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: nil) == date("2026-10-27T12:30:00Z"))
  }

  @Test func retryNeverPassesTheNextRotation() {
    let now = date("2026-10-28T03:25:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: nil) == date("2026-10-28T03:40:00Z"))
  }

  @Test func retryDuringSettleWindowDoesNotPassItsDeadline() {
    let now = date("2026-10-27T03:35:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: "2026-10-26") == date("2026-10-27T03:40:00Z"))
  }

  @Test func widgetImageDecodeAndOutputStayWithinThePixelBudget() {
    let requested = CGSize(width: 1_200, height: 2_400)
    let bounded = PrismWotdImageBudget.boundedPixels(requested)
    #expect(bounded.width * bounded.height <= CGFloat(PrismWotdImageBudget.maximumPixels))
    #expect(bounded == CGSize(width: 599, height: 1_198))
    #expect(PrismWotdImageBudget.thumbnailMaxPixelSize(source: CGSize(width: 4_000, height: 6_000), filling: bounded) == 1_198)
  }

  @Test func panoramaDecodeDoesNotUseItsUnboundedSourceLongEdge() {
    let requested = PrismWotdImageBudget.boundedPixels(CGSize(width: 1_200, height: 1_200))
    #expect(PrismWotdImageBudget.thumbnailMaxPixelSize(
      source: CGSize(width: 100_000, height: 1_000), filling: requested
    ) == 17_320)
  }

  @Test func portraitWallKeepsItsWidthInAWideWidget() {
    #expect(PrismWotdImageBudget.thumbnailMaxPixelSize(
      source: CGSize(width: 1_080, height: 2_340), filling: CGSize(width: 1_092, height: 510)
    ) == 2_340)
  }

  @Test func streamedImageBytesStopAtTheConfiguredLimit() async throws {
    let source = WidgetByteSource(count: 1_000)
    let bytes = AsyncStream<UInt8>(unfolding: { await source.next() })
    await #expect(throws: URLError.self) { try await PrismWotdBytes.read(bytes, limit: 100) }
    #expect(await source.readCount == 101)
    let exact = WidgetByteSource(count: 100)
    let data = try await PrismWotdBytes.read(AsyncStream<UInt8>(unfolding: { await exact.next() }), limit: 100)
    #expect(data == Data(repeating: 42, count: 100))
  }

  @Test func concurrentRefreshesShareTheLoadAndFailedFetchDoesNotPoisonRetries() async {
    let coordinator = PrismWotdRefreshCoordinator()
    let probe = WidgetRefreshProbe()
    let first = await coordinator.task { await probe.load() }
    await probe.waitUntilStarted()
    let second = await coordinator.task {
      await probe.recordExtraLoad()
      return (nil, "unshared")
    }
    await probe.release()
    #expect(await first.value.wall == nil)
    #expect(await second.value.wall == nil)
    #expect(await second.value.pickedDay == nil)
    #expect(await probe.calls == 1)
    let retry = await coordinator.task { (nil, "2026-10-27") }
    #expect(await retry.value.pickedDay == "2026-10-27")
  }

  // MARK: Kept today

  @Test func keptTodayUntilLocalMidnight() {
    // 23:59 in India (UTC+5:30).
    let display = PrismStreakRule.display(snapshot(), at: date("2026-10-27T18:29:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: true))
  }

  @Test func afterLocalMidnightTheStreakLivesButTodayIsOpen() {
    // 00:01 on 28 October in India.
    let display = PrismStreakRule.display(snapshot(), at: date("2026-10-27T18:31:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: false))
  }

  @Test func aFutureKeptDayDoesNotCountAsKeptToday() {
    let display = PrismStreakRule.display(snapshot(day: "2026-10-28"), at: date("2026-10-27T06:00:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: false))
  }

  @Test func theSameInstantIsStillTheKeptDayWestOfUTC() {
    // 11:31 on 27 October in California (UTC-7).
    let display = PrismStreakRule.display(snapshot(offset: -420), at: date("2026-10-27T18:31:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: true))
  }

  @Test func aMissedDayEndsTheStreakWithoutAFreeze() {
    let display = PrismStreakRule.display(snapshot(), at: date("2026-10-29T06:00:00Z"))
    #expect(display == PrismStreakDisplay(count: 0, keptToday: false))
  }

  @Test func aFreezeCoversAMissedDay() {
    let display = PrismStreakRule.display(snapshot(freezes: 1), at: date("2026-10-29T06:00:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: false))
  }

  @Test func signedOutHasNoStreak() {
    #expect(PrismStreakRule.display(nil, at: date("2026-10-27T06:00:00Z")) == nil)
  }

  @Test func anUnreadableDayShowsNoStreak() {
    let display = PrismStreakRule.display(snapshot(day: "2026-13-01"), at: date("2026-10-27T06:00:00Z"))
    #expect(display == PrismStreakDisplay(count: 0, keptToday: false))
  }

  @Test func timelineTurnsOverAtLocalMidnights() {
    let midnights = PrismStreakRule.midnights(after: date("2026-10-27T18:00:00Z"), utcOffsetMinutes: 330, count: 2)
    #expect(midnights == [date("2026-10-27T18:30:00Z"), date("2026-10-28T18:30:00Z")])
  }

  @Test func snapshotRoundTripsAndClears() throws {
    let suite = "PrismWidgetCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    PrismStreakStore.save(snapshot(), to: defaults)
    #expect(PrismStreakStore.load(from: defaults) == snapshot())
    PrismStreakStore.save(nil, to: defaults)
    #expect(PrismStreakStore.load(from: defaults) == nil)
  }

  @Test func cacheManifestNeverPairsAStaleWallWithAnotherImagesBytes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let image = directory.appendingPathComponent("image-current")
    try Data([1]).write(to: image)
    let oldWall = PrismWotdWall(
      documentId: "old", shareId: "old", imageURL: URL(string: "https://cdn.example.com/old.jpg")!,
      title: nil, creator: nil, pickedDay: "2026-10-26"
    )
    let currentWall = PrismWotdWall(
      documentId: "current", shareId: "current", imageURL: URL(string: "https://cdn.example.com/current.jpg")!,
      title: nil, creator: nil, pickedDay: "2026-10-27"
    )
    let manifest = PrismWotdCacheManifest(wall: oldWall, imageFileName: image.lastPathComponent)
    #expect(manifest.imageFile(in: directory, for: oldWall) == image)
    #expect(manifest.imageFile(in: directory, for: currentWall) == nil)
  }

  #if canImport(ImageIO)
  private func imageData(width: Int = 64, height: Int = 64) throws -> Data {
    let context = try #require(CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
    try #require(CGImageDestinationFinalize(destination))
    return data as Data
  }

  private func wall(_ id: String) -> PrismWotdWall {
    PrismWotdWall(
      documentId: id, shareId: id, imageURL: URL(string: "https://cdn.example.com/\(id).png")!,
      title: id, creator: nil, pickedDay: "2026-10-27"
    )
  }

  @Test func actualPanoramaDecodeAndCropStayWithinThePixelBudget() throws {
    let data = try imageData(width: 4_096, height: 1_024)
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: file) }
    try data.write(to: file)
    let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
    let requested = CGSize(width: 1_200, height: 2_400)
    let thumbnail = try #require(PrismWotdImage.thumbnail(source, filling: requested))
    #expect(thumbnail.width * thumbnail.height <= PrismWotdImageBudget.maximumDecodePixels)
    let cropped = try #require(PrismWotdImage.decode(source, filling: requested))
    #expect(cropped.width * cropped.height <= PrismWotdImageBudget.maximumPixels)
    #expect(abs(Double(cropped.width) / Double(cropped.height) - 0.5) < 0.01)
  }

  @Test func portraitWallFillsAMediumWidgetAtFullWidth() throws {
    let data = try imageData(width: 1_080, height: 2_340)
    let cropped = try #require(PrismWotdImage.decode(data, filling: CGSize(width: 1_092, height: 510)))
    #expect(cropped.width == 1_080)
    #expect(abs(Double(cropped.width) / Double(cropped.height) - 1_092.0 / 510.0) < 0.01)
  }

  @Test func metadataOnlyRefreshNeverRequestsOrDecodesAnImage() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = PrismWotdDiskCache(directory: directory)
    try await cache.update(wall("metadata"), includeImage: false) { throw URLError(.cannotDecodeContentData) }
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    try cache.save(wall("old"), image: imageData())
    let previous = cache.load()
    try await cache.update(wall("new"), includeImage: false) { throw URLError(.cannotDecodeContentData) }
    #expect(cache.load() == previous)
    try await cache.update(wall("new"), includeImage: true) { try imageData(width: 32, height: 32) }
    #expect(cache.load()?.wall == wall("new"))
  }

  @Test func unusableCurrentWallRetainsTheCacheAndRetriesInsteadOfWaitingUntilTomorrow() throws {
    let identity = try PrismShortcutWotdIdentity.pointer(pointer)
    let cached = wall("old")
    let result = PrismWotdSelection.resolve(
      pointer: identity, document: Data(#"{"fields":{}}"#.utf8), cached: cached
    )
    #expect(result.wall == cached)
    #expect(result.pickedDay == nil)
    #expect(PrismWotdSchedule.nextRefresh(after: date("2026-10-27T12:00:00Z"), pickedDay: result.pickedDay)
      == date("2026-10-27T12:30:00Z"))
  }

  @Test func failedManifestPublicationRetainsThePreviousImageAndMetadata() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = PrismWotdDiskCache(directory: directory)
    let image = try imageData()
    let newImage = try imageData(width: 32, height: 32)
    try cache.save(wall("old"), image: image)
    let previous = try #require(cache.load())
    #expect(throws: CocoaError.self) {
      try cache.save(wall("new"), image: newImage, publish: { _, _ in throw CocoaError(.fileWriteNoPermission) })
    }
    #expect(cache.load() == previous)
    let previousImage = try #require(previous.imageFile(in: directory, for: wall("old")))
    #expect(try Data(contentsOf: previousImage) == image)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 2)
    try cache.save(wall("new"), image: newImage)
    let current = try #require(cache.load())
    #expect(current.wall == wall("new"))
    #expect(current.imageFile(in: directory, for: wall("old")) == nil)
    #expect(try Data(contentsOf: previousImage) == image)
    #expect(current.imageFileName != previous.imageFileName)
  }

  @Test func recognizedButTruncatedImageDoesNotReplaceTheValidCache() throws {
    let data = try imageData()
    let truncated = Data(data.prefix(33))
    let source = try #require(CGImageSourceCreateWithData(truncated as CFData, nil))
    #expect(CGImageSourceGetCount(source) > 0)
    #expect(PrismWotdImage.decode(truncated, filling: CGSize(width: 32, height: 32)) == nil)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = PrismWotdDiskCache(directory: directory)
    try cache.save(wall("valid"), image: data)
    let previous = cache.load()
    #expect(throws: URLError.self) { try cache.save(wall("truncated"), image: truncated) }
    #expect(cache.load() == previous)
  }
  #endif

  // MARK: Wall of the Day REST parsing

  private let pointer = Data(
    #"{"fields":{"wallId":{"stringValue":"doc-1"},"date":{"timestampValue":"2026-10-27T03:30:12.5Z"}}}"#.utf8
  )

  @Test func parsesTheWallWithItsDisplayImage() throws {
    let wall = Data(#"""
      {"fields":{"id":{"stringValue":"share-1"},"title":{"stringValue":" Dusk "},"by":{"stringValue":"Akshay"},
      "wallpaper_thumb":{"stringValue":"https://cdn.example.com/t/1.jpg"},
      "wallpaper_url":{"stringValue":"https://cdn.example.com/o/1.png"}}}
      """#.utf8)
    let parsed = PrismWotdParser.wall(pointer: try PrismShortcutWotdIdentity.pointer(pointer), document: wall)
    #expect(parsed == PrismWotdWall(
      documentId: "doc-1",
      shareId: "share-1",
      imageURL: URL(string: "https://cdn.example.com/t/1.jpg")!,
      title: "Dusk",
      creator: "Akshay",
      pickedDay: "2026-10-27"
    ))
  }

  @Test func missingDisplayImageNeverFallsBackToTheOriginal() throws {
    let wall = Data(#"{"fields":{"wallpaper_url":{"stringValue":"https://cdn.example.com/o/1.png"}}}"#.utf8)
    #expect(PrismWotdParser.wall(pointer: try PrismShortcutWotdIdentity.pointer(pointer), document: wall) == nil)
  }

  @Test func blankOrInsecureImageIsMissing() throws {
    let identity = try PrismShortcutWotdIdentity.pointer(pointer)
    let blank = Data(#"{"fields":{"wallpaper_thumb":{"stringValue":"  "}}}"#.utf8)
    let insecure = Data(#"{"fields":{"wallpaper_thumb":{"stringValue":"http://cdn.example.com/t.jpg"}}}"#.utf8)
    #expect(PrismWotdParser.wall(pointer: identity, document: blank) == nil)
    #expect(PrismWotdParser.wall(pointer: identity, document: insecure) == nil)
  }

  @Test func shareIdFallsBackToTheDocumentId() throws {
    let wall = Data(#"{"fields":{"wallpaper_thumb":{"stringValue":"https://cdn.example.com/t.jpg"}}}"#.utf8)
    let parsed = PrismWotdParser.wall(pointer: try PrismShortcutWotdIdentity.pointer(pointer), document: wall)
    #expect(parsed?.shareId == "doc-1")
    #expect(parsed?.title == nil)
  }

  @Test func wallLinkIsTheShareLinkWithTheWidgetKind() {
    let wall = PrismWotdWall(
      documentId: "doc-1", shareId: "share 1", imageURL: URL(string: "https://cdn.example.com/t.jpg?w=1&h=2")!,
      title: nil, creator: nil, pickedDay: "2026-10-27"
    )
    #expect(PrismWidgetLink.wall(wall, widget: "wotd_small")?.absoluteString
      == "prism://share?id=share%201&source=prism&thumb=https%3A%2F%2Fcdn.example.com%2Ft.jpg%3Fw%3D1%26h%3D2&widget=wotd_small")
    #expect(PrismWidgetLink.streak(widget: "streak_inline")?.absoluteString == "prism://streak?widget=streak_inline")
  }
}

private actor WidgetByteSource {
  let count: Int
  private(set) var readCount = 0

  init(count: Int) { self.count = count }

  func next() -> UInt8? {
    guard readCount < count else { return nil }
    readCount += 1
    return 42
  }
}

private actor WidgetRefreshProbe {
  private(set) var calls = 0
  private var releaseContinuation: CheckedContinuation<Void, Never>?
  private var startContinuation: CheckedContinuation<Void, Never>?

  func recordExtraLoad() { calls += 1 }

  func load() async -> PrismWotdRefreshCoordinator.Result {
    calls += 1
    startContinuation?.resume()
    startContinuation = nil
    await withCheckedContinuation { releaseContinuation = $0 }
    return (nil, nil)
  }

  func waitUntilStarted() async {
    if calls > 0 { return }
    await withCheckedContinuation { startContinuation = $0 }
  }

  func release() {
    releaseContinuation?.resume()
    releaseContinuation = nil
  }
}
