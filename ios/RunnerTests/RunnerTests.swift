import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testDownloadSavesWallpaperToPhotos() throws {
    let image = Data([0x89, 0x50, 0x4E, 0x47])
    let source = FileManager.default.temporaryDirectory.appendingPathComponent("prism-test-wall.png")
    try image.write(to: source)
    var saved: [Data] = []
    let api = PrismMediaHostApiImpl(savePhoto: { saved.append($0) })

    let result = try download(api, link: source.path)

    XCTAssertTrue(result.success)
    XCTAssertEqual(saved, [image])
  }

  func testDownloadFailsWhenPhotosRefuses() throws {
    let source = FileManager.default.temporaryDirectory.appendingPathComponent("prism-test-denied.png")
    try Data([0x1]).write(to: source)
    struct PhotosDenied: Error {}
    let api = PrismMediaHostApiImpl(savePhoto: { _ in throw PhotosDenied() })

    let result = try download(api, link: source.path)

    XCTAssertFalse(result.success)
  }

  func testDownloadDoesNotBlockTheCallingThread() throws {
    let source = FileManager.default.temporaryDirectory.appendingPathComponent("prism-test-slow.png")
    try Data([0x1]).write(to: source)
    let api = PrismMediaHostApiImpl(savePhoto: { _ in Thread.sleep(forTimeInterval: 1) })
    let done = expectation(description: "download finished")

    let started = Date()
    api.enqueueDownload(request: DownloadRequest(link: source.path, filenameWithoutExtension: "prism-test-slow")) { _ in
      XCTAssertTrue(Thread.isMainThread)
      done.fulfill()
    }

    XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
    wait(for: [done], timeout: 5)
  }

  private func download(_ api: PrismMediaHostApiImpl, link: String) throws -> OperationResult {
    let done = expectation(description: "download finished")
    var outcome: Result<OperationResult, Error>?
    api.enqueueDownload(request: DownloadRequest(link: link, filenameWithoutExtension: "prism-test")) {
      outcome = $0
      done.fulfill()
    }
    wait(for: [done], timeout: 5)
    return try XCTUnwrap(outcome).get()
  }
}
