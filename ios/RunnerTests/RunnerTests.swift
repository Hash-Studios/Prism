import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testDownloadSavesWallpaperToPhotos() throws {
    let image = Data([0x89, 0x50, 0x4E, 0x47])
    let source = FileManager.default.temporaryDirectory.appendingPathComponent("prism-test-wall.png")
    try image.write(to: source)
    var saved: [Data] = []
    let api = PrismMediaHostApiImpl(savePhoto: { saved.append($0) })

    let result = try api.enqueueDownload(
      request: DownloadRequest(link: source.path, filenameWithoutExtension: "prism-test-wall"))

    XCTAssertTrue(result.success)
    XCTAssertEqual(saved, [image])
  }

  func testDownloadFailsWhenPhotosRefuses() throws {
    let source = FileManager.default.temporaryDirectory.appendingPathComponent("prism-test-denied.png")
    try Data([0x1]).write(to: source)
    struct PhotosDenied: Error {}
    let api = PrismMediaHostApiImpl(savePhoto: { _ in throw PhotosDenied() })

    let result = try api.enqueueDownload(
      request: DownloadRequest(link: source.path, filenameWithoutExtension: "prism-test-denied"))

    XCTAssertFalse(result.success)
  }
}
