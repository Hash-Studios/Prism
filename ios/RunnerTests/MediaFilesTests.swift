import Foundation
import Testing

#if canImport(PrismMediaStorage)
@testable import PrismMediaStorage
#else
@testable import Runner
#endif

struct MediaFilesTests {
  @Test(arguments: ["", " ", ".", "..", "../escape", "/escape", "a/b", "a\\b", "a\n", "a\0", String(repeating: "é", count: 101)])
  func invalidFilenames(_ filename: String) {
    #expect(throws: PrismMediaError.self) { try PrismMediaFiles.validateFilename(filename) }
  }

  @Test(arguments: ["https:///", "https://user:secret@example.com/image", "https://user@example.com/image", "file:///image.png", "content://image", "/tmp/image", "javascript:alert(1)"])
  func invalidNetworkSources(_ link: String) {
    #expect(throws: PrismMediaError.self) { try PrismMediaFiles.networkURL(link) }
  }

  @Test func localFileURLsDecodeSpacesAndUseImageContent() async throws {
    let fixture = try MediaFixture()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads)
    let image = try await files.resolve(link: fixture.source.absoluteString, isLocalFile: true)
    #expect(image.url == fixture.source)
    #expect(image.fileExtension == "png")
    #expect(!image.isTemporary)
  }

  @Test func invalidImagesAndOversizedLocalFilesFail() async throws {
    let fixture = try MediaFixture()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads)
    try Data("<html>not an image</html>".utf8).write(to: fixture.source)
    await #expect(throws: PrismMediaError.self) { try await files.resolve(link: fixture.source.path, isLocalFile: true) }
    try Data().write(to: fixture.source)
    await #expect(throws: PrismMediaError.self) { try await files.resolve(link: fixture.source.path, isLocalFile: true) }
    let handle = try FileHandle(forWritingTo: fixture.source)
    try handle.truncate(atOffset: UInt64(PrismMediaFiles.maximumImageBytes + 1))
    try handle.close()
    await #expect(throws: PrismMediaError.self) { try await files.resolve(link: fixture.source.path, isLocalFile: true) }
  }

  @Test func mislabelledLocalImageUsesTemporaryTypedCopyAndPreservesOriginal() async throws {
    let fixture = try MediaFixture()
    let source = fixture.root.appendingPathComponent("mislabelled.tmp")
    let bytes = try Data(contentsOf: fixture.source)
    try bytes.write(to: source)
    let files = PrismMediaFiles()
    let image = try await files.resolve(link: source.path, isLocalFile: true)
    #expect(image.url.pathExtension == "png")
    #expect(image.originalFilename == "mislabelled.png")
    #expect(image.isTemporary)
    #expect(try Data(contentsOf: image.url) == bytes)
    await files.removeTemporarySource(image)
    #expect(!FileManager.default.fileExists(atPath: image.url.path))
    #expect(try Data(contentsOf: source) == bytes)
  }

  @Test func httpErrorsDiscardNetworkFiles() async throws {
    let fixture = try MediaFixture()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads, download: fixture.downloader(status: 404))
    await #expect(throws: PrismMediaError.self) { try await files.resolve(link: "https://example.com/wall", isLocalFile: false) }
    let contents = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
    #expect(contents == [fixture.source.lastPathComponent])
  }

  @Test func stagedDownloadIsHiddenAndDuplicateNamesPreservePreviousFile() async throws {
    let fixture = try MediaFixture()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads, download: fixture.downloader())
    let image = try await files.resolve(link: "https://example.com/wall.jpg", isLocalFile: false)
    #expect(image.url.pathExtension == "png")
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path) == [fixture.source.lastPathComponent])
    let stage = try await files.stage(image: image, filename: "wall")
    await files.removeTemporarySource(image)
    #expect(!FileManager.default.fileExists(atPath: image.url.path))
    #expect(try await files.list().isEmpty)
    let first = try await files.commit(staged: stage, filename: "wall")
    #expect(first.lastPathComponent == "wall.png")
    let firstBytes = try Data(contentsOf: first)
    let local = try await files.resolve(link: fixture.source.path, isLocalFile: true)
    let secondStage = try await files.stage(image: local, filename: "wall")
    let second = try await files.commit(staged: secondStage, filename: "wall")
    #expect(second.lastPathComponent == "wall (1).png")
    #expect(try Data(contentsOf: first) == firstBytes)
    #expect(try await files.list().map(\.lastPathComponent) == ["wall (1).png", "wall.png"])
  }

  @Test func discardKeepsPreviousDownloadAndSource() async throws {
    let fixture = try MediaFixture()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads)
    let image = try await files.resolve(link: fixture.source.path, isLocalFile: true)
    let previous = try await files.commit(staged: files.stage(image: image, filename: "wall"), filename: "wall")
    let stage = try await files.stage(image: image, filename: "wall")
    await files.discard(staged: stage)
    let listed = try await files.list().map { $0.resolvingSymlinksInPath().path }
    #expect(listed == [previous.resolvingSymlinksInPath().path])
    #expect(FileManager.default.fileExists(atPath: fixture.source.path))
    #expect(!FileManager.default.fileExists(atPath: stage.path))
  }

  @Test func clearRemovesCompletedFilesAndAllowsStagedDownloadToFinish() async throws {
    let fixture = try MediaFixture()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads)
    let image = try await files.resolve(link: fixture.source.path, isLocalFile: true)
    let completed = try await files.commit(staged: files.stage(image: image, filename: "old"), filename: "old")
    let staged = try await files.stage(image: image, filename: "new")
    #expect(try await files.clear())
    #expect(!FileManager.default.fileExists(atPath: completed.path))
    #expect(FileManager.default.fileExists(atPath: staged.path))
    let newFile = try await files.commit(staged: staged, filename: "new")
    let listed = try await files.list().map { $0.resolvingSymlinksInPath().path }
    #expect(listed == [newFile.resolvingSymlinksInPath().path])
    #expect(try await files.clear())
    #expect(try await !files.clear())
  }
}
