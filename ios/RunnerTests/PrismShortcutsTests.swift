import Foundation
import Testing

#if canImport(PrismShortcutsCore)
@testable import PrismShortcutsCore
#endif
#if canImport(Runner)
@testable import Runner
#endif

struct PrismShortcutsTests {
  @Test func wallOfTheDayPrefersFreshRemoteURLWhenAvailable() throws {
    let cached = URL(string: "https://example.com/retained.jpg")!
    let fresh = URL(string: "https://example.com/current.jpg")!

    let result = try PrismShortcutWallpaperFallback.resolve(fresh: .success(fresh), retained: cached)

    #expect(result == fresh)
  }

  @Test func wallOfTheDayUsesRetainedURLWhenRemoteLookupFails() throws {
    let cached = URL(string: "https://example.com/retained.jpg")!

    let result = try PrismShortcutWallpaperFallback.resolve(fresh: .failure(TestFailure.remote), retained: cached)

    #expect(result == cached)
  }

  @Test func wallOfTheDayPropagatesRemoteFailureWithoutRetainedURL() {
    do {
      _ = try PrismShortcutWallpaperFallback.resolve(fresh: .failure(TestFailure.remote), retained: nil)
      Issue.record("Expected remote lookup failure")
    } catch {
      #expect(error as? TestFailure == .remote)
    }
  }

#if canImport(Runner)
  @Test func offlineSupportRootIsCreatedAndExcludedFromBackupAtStartup() throws {
    let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: support) }

    let root = try #require(Runner.AppDelegate.prepareOfflineRoot(at: support))

    #expect(FileManager.default.fileExists(atPath: root.path))
    #expect(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
  }

  @Test func imageTransfersKeepSixtySecondResourceTimeoutAndMetadataRemainsBounded() {
    #expect(PrismShortcutWallpaperLoader.imageSession.configuration.timeoutIntervalForResource == 60)
    #expect(PrismShortcutWallpaperLoader.metadataSession.configuration.timeoutIntervalForResource == 20)
  }
#endif

  private enum TestFailure: Error, Equatable {
    case remote
  }

  private func favourite(_ id: String) -> PrismShortcutFavourite {
    PrismShortcutFavourite(id: id, url: URL(string: "https://example.com/\(id).jpg")!)
  }

  @Test func parseKeepsOrderAndValues() {
    let json = #"[{"id":"b","url":"https://example.com/b.jpg"},{"id":"a","url":"https://example.com/a.png"}]"#
    let second = PrismShortcutFavourite(id: "a", url: URL(string: "https://example.com/a.png")!)
    #expect(PrismShortcutFavourites.parse(json) == [favourite("b"), second])
  }

  @Test(arguments: [nil, "", "[]", "not json", "{}", #"{"id":"a"}"#])
  func parseReturnsEmptyForMissingOrInvalidJSON(_ json: String?) {
    #expect(PrismShortcutFavourites.parse(json).isEmpty)
  }

  @Test func parseSkipsMalformedEntries() {
    let json = """
      [{"id":"","url":"https://example.com/a.jpg"},{"id":"b"},{"url":"https://example.com/c.jpg"},
      {"id":"d","url":"http://example.com/d.jpg"},{"id":"e","url":"not a url"},{"id":5,"url":"https://example.com/f.jpg"},
      "text",{"id":"ok","url":"https://example.com/ok.jpg"}]
      """
    #expect(PrismShortcutFavourites.parse(json) == [favourite("ok")])
  }

  @Test func parseCapsAtTwoHundred() {
    let items = (0..<250).map { #"{"id":"w\#($0)","url":"https://example.com/\#($0).jpg"}"# }
    let parsed = PrismShortcutFavourites.parse("[" + items.joined(separator: ",") + "]")
    #expect(parsed.count == 200)
    #expect(parsed.first?.id == "w0")
    #expect(parsed.last?.id == "w199")
  }

  @Test func pickReturnsNilWithoutFavourites() {
    #expect(PrismShortcutFavourites.pick(from: [], excluding: nil) == nil)
    #expect(PrismShortcutFavourites.pick(from: [], excluding: "a") == nil)
  }

  @Test func pickReturnsTheOnlyFavouriteEvenWhenItWasLast() {
    let only = [favourite("a")]
    #expect(PrismShortcutFavourites.pick(from: only, excluding: "a") == favourite("a"))
    #expect(PrismShortcutFavourites.pick(from: only, excluding: nil) == favourite("a"))
  }

  @Test func pickAvoidsTheLastPickedFavourite() {
    let all = [favourite("a"), favourite("b"), favourite("c")]
    for index in 0..<2 {
      let picked = PrismShortcutFavourites.pick(from: all, excluding: "a", randomIndex: { _ in index })
      #expect(picked?.id != "a")
    }
    #expect(PrismShortcutFavourites.pick(from: all, excluding: "a", randomIndex: { _ in 0 }) == favourite("b"))
    #expect(PrismShortcutFavourites.pick(from: all, excluding: "a", randomIndex: { _ in 1 }) == favourite("c"))
  }

  @Test func pickDrawsFromAllWhenThereIsNoLastPick() {
    let all = [favourite("a"), favourite("b")]
    #expect(PrismShortcutFavourites.pick(from: all, excluding: nil, randomIndex: { _ in 0 }) == favourite("a"))
    #expect(PrismShortcutFavourites.pick(from: all, excluding: nil, randomIndex: { _ in 1 }) == favourite("b"))
  }

  @Test func pickFallsBackWhenEveryEntryIsTheLastPick() {
    let duplicates = [favourite("a"), favourite("a")]
    #expect(PrismShortcutFavourites.pick(from: duplicates, excluding: "a") == favourite("a"))
  }

  @Test func pickClampsOutOfRangeIndexes() {
    let all = [favourite("a"), favourite("b")]
    #expect(PrismShortcutFavourites.pick(from: all, excluding: nil, randomIndex: { _ in 99 }) == favourite("b"))
    #expect(PrismShortcutFavourites.pick(from: all, excluding: nil, randomIndex: { _ in -3 }) == favourite("a"))
  }

  @Test func documentURLHasFirestoreRESTShape() throws {
    let url = try #require(
      PrismFirestoreREST.documentURL(
        projectID: "prism-wallpapers", apiKey: "AIza-key", collection: "walls", documentID: "abc123"
      )
    )
    #expect(
      url.absoluteString
        == "https://firestore.googleapis.com/v1/projects/prism-wallpapers/databases/(default)/documents/walls/abc123?key=AIza-key"
    )
  }

  @Test func documentURLEncodesPathSeparators() throws {
    let url = try #require(
      PrismFirestoreREST.documentURL(projectID: "p", apiKey: "k", collection: "walls", documentID: "a/b")
    )
    #expect(url.absoluteString.contains("/documents/walls/a%2Fb?"))
  }

  @Test func documentURLRejectsEmptyParts() {
    #expect(PrismFirestoreREST.documentURL(projectID: "", apiKey: "k", collection: "walls", documentID: "a") == nil)
    #expect(PrismFirestoreREST.documentURL(projectID: "p", apiKey: "", collection: "walls", documentID: "a") == nil)
    #expect(PrismFirestoreREST.documentURL(projectID: "p", apiKey: "k", collection: "", documentID: "a") == nil)
    #expect(PrismFirestoreREST.documentURL(projectID: "p", apiKey: "k", collection: "walls", documentID: "") == nil)
  }

  @Test func stringFieldReadsFirestoreValues() {
    let json = #"{"name":"projects/p/databases/(default)/documents/walls/a","fields":{"wallId":{"stringValue":"abc"},"count":{"integerValue":"3"},"empty":{"stringValue":""}}}"#
    let data = Data(json.utf8)
    #expect(PrismFirestoreREST.stringField("wallId", in: data) == "abc")
    #expect(PrismFirestoreREST.stringField("count", in: data) == nil)
    #expect(PrismFirestoreREST.stringField("empty", in: data) == nil)
    #expect(PrismFirestoreREST.stringField("missing", in: data) == nil)
    #expect(PrismFirestoreREST.stringField("wallId", in: Data("[]".utf8)) == nil)
    #expect(PrismFirestoreREST.stringField("wallId", in: Data("oops".utf8)) == nil)
  }

  @Test func imageKindDetectsJPEGAndPNG() {
    #expect(PrismShortcutImageKind(data: Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])) == .jpeg)
    #expect(PrismShortcutImageKind(data: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])) == .png)
    #expect(PrismShortcutImageKind.jpeg.filenameExtension == "jpg")
    #expect(PrismShortcutImageKind.png.filenameExtension == "png")
  }

  @Test func imageKindRejectsOtherData() {
    #expect(PrismShortcutImageKind(data: Data()) == nil)
    #expect(PrismShortcutImageKind(data: Data([0xFF, 0xD8])) == nil)
    #expect(PrismShortcutImageKind(data: Data("RIFF....WEBP".utf8)) == nil)
    #expect(PrismShortcutImageKind(data: Data([0x89, 0x50, 0x4E, 0x47])) == nil)
  }

  @Test func localFileResolverAcceptsOnlyContainedNonemptyImageFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let image = root.appendingPathComponent("assets/wall.png")
    try FileManager.default.createDirectory(at: image.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).write(to: image)

    #expect(
      PrismShortcutLocalFileResolver.resolve(path: "assets/wall.png", roots: [root], maximumBytes: 1024) == image
    )
    #expect(PrismShortcutLocalFileResolver.resolve(path: "../wall.png", roots: [root], maximumBytes: 1024) == nil)
    #expect(PrismShortcutLocalFileResolver.resolve(path: image.path, roots: [root], maximumBytes: 1024) == nil)
    #expect(PrismShortcutLocalFileResolver.resolve(path: "missing.png", roots: [root], maximumBytes: 1024) == nil)

    let invalid = root.appendingPathComponent("assets/invalid.png")
    try Data([1, 2, 3]).write(to: invalid)
    #expect(PrismShortcutLocalFileResolver.resolve(path: "assets/invalid.png", roots: [root], maximumBytes: 1024) == nil)
  }

  @Test func localFileResolverRejectsFilesAboveTheImageReadLimit() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let image = root.appendingPathComponent("oversized.png")
    try Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).write(to: image)
    let handle = try FileHandle(forWritingTo: image)
    try handle.truncate(atOffset: 40 * 1024 * 1024 + 1)
    try handle.close()

    #expect(
      PrismShortcutLocalFileResolver.resolve(
        path: "oversized.png",
        roots: [root],
        maximumBytes: 40 * 1024 * 1024
      ) == nil
    )
  }
}
