#if os(iOS) && !canImport(PrismMediaStorage)
import AVFoundation
import ImageIO
import Photos
import UniformTypeIdentifiers
import XCTest

@testable import Runner

/// Needs Photos access for the app under test: `xcrun simctl privacy <udid> grant photos com.hash.prism`.
final class LivePhotoExportTests: XCTestCase {
  private var directory: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  func testExportedPairSharesOneIdentifierAndSavesAsLivePhoto() async throws {
    let files = try await PrismLivePhotoExporter.render(request(style: .drift), into: directory) { _ in }

    let source = try XCTUnwrap(CGImageSourceCreateWithURL(files.photo as CFURL, nil))
    let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    let makerApple = properties[kCGImagePropertyMakerAppleDictionary] as? [String: Any]
    XCTAssertEqual(makerApple?["17"] as? String, files.contentIdentifier)
    XCTAssertEqual(CGImageSourceGetCount(source), 1)

    let video = AVURLAsset(url: files.video)
    let items = AVMetadataItem.metadataItems(
      from: try await video.load(.metadata), filteredByIdentifier: .quickTimeMetadataContentIdentifier
    )
    let identifier = try await XCTUnwrap(items.first).load(.stringValue)
    XCTAssertEqual(identifier, files.contentIdentifier)
    let duration = try await video.load(.duration)
    XCTAssertEqual(duration.seconds, 1.0, accuracy: 0.05)
    let videoTracks = try await video.loadTracks(withMediaType: .video)
    let naturalSize = try await XCTUnwrap(videoTracks.first).load(.naturalSize)
    XCTAssertEqual(naturalSize, CGSize(width: 390, height: 844))
    let metadataTracks = try await video.loadTracks(withMediaType: .metadata)
    XCTAssertEqual(metadataTracks.count, 1)

    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    try XCTSkipUnless(status == .authorized || status == .limited, "Photos access is not granted")
    let assetId = try await PrismLivePhotoLibrary.save(files)
    let asset = try XCTUnwrap(PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject)
    XCTAssertTrue(asset.mediaSubtypes.contains(.photoLive))
    XCTAssertEqual(PrismLivePhotoLibrary.isLivePhoto(localIdentifier: assetId), true)
  }

  func testEveryStyleRenders() async throws {
    let depth = directory.appendingPathComponent("depth.jpg")
    try writeFixture(to: depth, gray: true)
    for style in LivePhotoStyle.allCases {
      let folder = directory.appendingPathComponent("\(style)", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      var styleRequest = request(style: style)
      styleRequest.depthPath = style == .depth ? depth.path : nil
      let files = try await PrismLivePhotoExporter.render(styleRequest, into: folder) { _ in }
      XCTAssertTrue(FileManager.default.fileExists(atPath: files.video.path), "\(style)")
    }
  }

  func testCancelReturnsCancelledAndRemovesFiles() async throws {
    let started = expectation(description: "first frame")
    started.assertForOverFulfill = false
    let breathe = request(style: .breathe, durationMs: 3000)
    let export = Task {
      await PrismLivePhotoExporter.export(breathe) { _ in started.fulfill() }
    }
    await fulfillment(of: [started], timeout: 30)
    export.cancel()
    let result = await export.value
    XCTAssertEqual(result.status, .cancelled)
    XCTAssertEqual(try leftoverFiles(), [])
  }

  func testTimeLimitReturnsTimedOutAndRemovesFiles() async throws {
    var shimmer = request(style: .shimmer, durationMs: 3000)
    shimmer.timeoutMs = 1
    let result = await PrismLivePhotoExporter.export(shimmer) { _ in }
    XCTAssertEqual(result.status, .timedOut)
    XCTAssertEqual(try leftoverFiles(), [])
  }

  func testInvalidRequestsFail() async throws {
    var depthWithoutMap = request(style: .depth)
    depthWithoutMap.depthPath = nil
    var tooLong = request(style: .drift)
    tooLong.durationMs = 4000
    var badRate = request(style: .drift)
    badRate.framesPerSecond = 60
    for invalid in [depthWithoutMap, tooLong, badRate] {
      do {
        _ = try await PrismLivePhotoExporter.render(invalid, into: directory) { _ in }
        XCTFail("expected invalid-request")
      } catch {
        XCTAssertEqual(error as? PrismLivePhotoFailure, .invalidRequest)
      }
    }
  }

  func testOutputSizeIsEvenAndInsideTheEncoderLimit() throws {
    XCTAssertEqual(try sizeOf(1179, 2556).width, 1178)
    XCTAssertEqual(try sizeOf(1179, 2556).height, 2556)
    XCTAssertLessThanOrEqual(try sizeOf(3000, 9000).height, PrismLivePhotoExporter.maximumSide)
    XCTAssertThrowsError(try PrismLivePhotoExporter.outputSize(width: 0, height: 10))
  }

  private func sizeOf(_ width: Int64, _ height: Int64) throws -> (width: Int, height: Int) {
    try PrismLivePhotoExporter.outputSize(width: width, height: height)
  }

  private func leftoverFiles() throws -> [String] {
    let root = PrismLivePhotoExporter.workRoot
    guard FileManager.default.fileExists(atPath: root.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(atPath: root.path)
  }

  private func request(style: LivePhotoStyle, durationMs: Int64 = 1000) -> LivePhotoExportRequest {
    let photo = directory.appendingPathComponent("photo.jpg")
    if !FileManager.default.fileExists(atPath: photo.path) { try? writeFixture(to: photo, gray: false) }
    return LivePhotoExportRequest(
      exportId: UUID().uuidString,
      photoPath: photo.path,
      depthPath: style == .depth ? photo.path : nil,
      style: style,
      widthPx: 390,
      heightPx: 844,
      durationMs: durationMs,
      framesPerSecond: 30,
      tint: 0xFF67_50A4,
      timeoutMs: 60_000
    )
  }

  private func writeFixture(to url: URL, gray: Bool) throws {
    let width = 390
    let height = 844
    let context = try XCTUnwrap(CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    let colors = gray
      ? [CGColor(red: 0, green: 0, blue: 0, alpha: 1), CGColor(red: 1, green: 1, blue: 1, alpha: 1)]
      : [CGColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1), CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1)]
    let gradient = try XCTUnwrap(CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: nil))
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
    let image = try XCTUnwrap(context.makeImage())
    let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
  }
}
#endif
