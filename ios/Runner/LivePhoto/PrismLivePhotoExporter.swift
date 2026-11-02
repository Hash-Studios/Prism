import AVFoundation
import CoreGraphics
import ImageIO
import Photos
import UniformTypeIdentifiers

enum PrismLivePhotoFailure: Error, Equatable {
  case invalidRequest
  case renderFailed
  case encodeFailed
  case saveFailed
  case notLive
  case timedOut

  var code: String {
    switch self {
    case .invalidRequest: return "invalid-request"
    case .renderFailed: return "render-failed"
    case .encodeFailed: return "encode-failed"
    case .saveFailed: return "save-failed"
    case .notLive: return "not-live"
    case .timedOut: return "timed-out"
    }
  }
}

/// The key photo and the paired video of one Live Photo, written with one shared content identifier.
struct PrismLivePhotoFiles: Sendable {
  let photo: URL
  let video: URL
  let contentIdentifier: String
}

/// Renders, pairs, saves and checks one Live Photo. Every step runs off the main thread.
enum PrismLivePhotoExporter {
  static let maximumSide = 4096
  static let maximumDurationMs = 3000
  static let framesPerSecondRange = 15...30
  static let workRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
    "prism-live-photo", isDirectory: true
  )

  private static let discardStaleWork: Void = {
    try? FileManager.default.removeItem(at: workRoot)
  }()

  static func makeWorkDirectory() throws -> URL {
    _ = discardStaleWork
    let directory = workRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Runs the whole export. [progress] gets 0 to 1 while frames render, from a background thread.
  static func export(
    _ request: LivePhotoExportRequest,
    progress: @escaping @Sendable (Double) -> Void
  ) async -> LivePhotoExportResult {
    switch await PrismLivePhotoLibrary.requestAddAccess() {
    case .authorized, .limited: break
    case .restricted: return LivePhotoExportResult(status: .permissionRestricted)
    default: return LivePhotoExportResult(status: .permissionDenied)
    }
    if Task.isCancelled { return LivePhotoExportResult(status: .cancelled) }
    do {
      let directory = try makeWorkDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let files = try await withTimeout(milliseconds: request.timeoutMs) {
        try await Task.detached(priority: .userInitiated) {
          try await render(request, into: directory, progress: progress)
        }.valueCancellingOnCancel()
      }
      if Task.isCancelled { return LivePhotoExportResult(status: .cancelled) }
      let assetId = try await PrismLivePhotoLibrary.save(files)
      let live = PrismLivePhotoLibrary.isLivePhoto(localIdentifier: assetId)
      if live == false {
        return LivePhotoExportResult(status: .failed, errorCode: PrismLivePhotoFailure.notLive.code, assetId: assetId)
      }
      return LivePhotoExportResult(status: .saved, assetId: assetId, verifiedLive: live)
    } catch is CancellationError {
      return LivePhotoExportResult(status: .cancelled)
    } catch PrismLivePhotoFailure.timedOut {
      return LivePhotoExportResult(status: .timedOut)
    } catch let failure as PrismLivePhotoFailure {
      return LivePhotoExportResult(status: .failed, errorCode: failure.code)
    } catch {
      return LivePhotoExportResult(status: .failed, errorCode: PrismLivePhotoFailure.encodeFailed.code)
    }
  }

  /// Writes the key photo and the paired video into [directory]. Throws `CancellationError` when the task is
  /// cancelled.
  static func render(
    _ request: LivePhotoExportRequest,
    into directory: URL,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> PrismLivePhotoFiles {
    let size = try outputSize(width: request.widthPx, height: request.heightPx)
    guard request.durationMs > 0, request.durationMs <= maximumDurationMs,
      framesPerSecondRange.contains(Int(request.framesPerSecond))
    else { throw PrismLivePhotoFailure.invalidRequest }
    let fps = Int32(request.framesPerSecond)
    let frameCount = max(2, Int(request.durationMs) * Int(fps) / 1000)
    let keyFrame = frameCount / 2
    let renderer = try PrismLivePhotoRenderer(
      style: request.style,
      photoURL: URL(fileURLWithPath: request.photoPath),
      depthURL: request.depthPath.map { URL(fileURLWithPath: $0) },
      tint: tintVector(request.tint)
    )
    let identifier = UUID().uuidString
    var photoURL = directory.appendingPathComponent("live.heic")
    let videoURL = directory.appendingPathComponent("live.mov")

    let writer: AVAssetWriter
    do {
      writer = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
    } catch {
      throw PrismLivePhotoFailure.encodeFailed
    }
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings(for: writer, size: size, fps: fps))
    videoInput.expectsMediaDataInRealTime = false
    let pixels = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: size.width,
        kCVPixelBufferHeightKey as String: size.height,
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ]
    )
    let stillInput = try stillImageTimeInput()
    let still = AVAssetWriterInputMetadataAdaptor(assetWriterInput: stillInput)
    guard writer.canAdd(videoInput), writer.canAdd(stillInput) else { throw PrismLivePhotoFailure.encodeFailed }
    writer.add(videoInput)
    writer.add(stillInput)
    writer.metadata = [contentIdentifierItem(identifier)]
    guard writer.startWriting() else { throw PrismLivePhotoFailure.encodeFailed }
    writer.startSession(atSourceTime: .zero)

    do {
      let frameDuration = CMTime(value: 1, timescale: fps)
      let stillTime = CMTimeMultiply(frameDuration, multiplier: Int32(keyFrame))
      try await waitUntilReady(stillInput, writer: writer)
      guard still.append(AVTimedMetadataGroup(
        items: [stillImageTimeItem()], timeRange: CMTimeRange(start: stillTime, duration: frameDuration)
      )) else { throw PrismLivePhotoFailure.encodeFailed }
      stillInput.markAsFinished()

      var wroteKeyPhoto = false
      for frame in 0..<frameCount {
        try Task.checkCancellation()
        guard let pool = pixels.pixelBufferPool else { throw PrismLivePhotoFailure.encodeFailed }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
          throw PrismLivePhotoFailure.encodeFailed
        }
        try renderer.render(phase: Float(frame) / Float(frameCount), into: buffer)
        if frame == keyFrame {
          photoURL = try writeKeyPhoto(from: buffer, to: photoURL, identifier: identifier)
          wroteKeyPhoto = true
        }
        try await waitUntilReady(videoInput, writer: writer)
        guard pixels.append(buffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frame))) else {
          throw PrismLivePhotoFailure.encodeFailed
        }
        progress(Double(frame + 1) / Double(frameCount))
      }
      guard wroteKeyPhoto else { throw PrismLivePhotoFailure.renderFailed }
      videoInput.markAsFinished()
      try await finishWriting(writer)
      guard writer.status == .completed else { throw PrismLivePhotoFailure.encodeFailed }
    } catch {
      if writer.status == .writing { writer.cancelWriting() }
      throw error
    }
    try Task.checkCancellation()
    return PrismLivePhotoFiles(photo: photoURL, video: videoURL, contentIdentifier: identifier)
  }

  /// Even sides inside the encoder limit, at the same aspect as asked.
  static func outputSize(width: Int64, height: Int64) throws -> (width: Int, height: Int) {
    guard width > 0, height > 0 else { throw PrismLivePhotoFailure.invalidRequest }
    let scale = min(1, Double(maximumSide) / Double(max(width, height)))
    let even = { (side: Int64) in max(2, Int((Double(side) * scale).rounded(.down)) & ~1) }
    return (even(width), even(height))
  }

  private static func tintVector(_ argb: Int64) -> SIMD4<Float> {
    let channel = { (shift: Int64) in Float((argb >> shift) & 0xFF) / 255 }
    return SIMD4(channel(16), channel(8), channel(0), 1)
  }

  private static func videoSettings(for writer: AVAssetWriter, size: (width: Int, height: Int), fps: Int32)
    -> [String: Any]
  {
    let bitsPerSecond = Double(size.width * size.height) * Double(fps) * 0.15
    func settings(_ codec: AVVideoCodecType) -> [String: Any] {
      [
        AVVideoCodecKey: codec,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: Int(bitsPerSecond),
          AVVideoExpectedSourceFrameRateKey: Int(fps),
          AVVideoMaxKeyFrameIntervalKey: Int(fps),
        ],
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
      ]
    }
    let hevc = settings(.hevc)
    return writer.canApply(outputSettings: hevc, forMediaType: .video) ? hevc : settings(.h264)
  }

  /// The QuickTime content identifier. The key photo carries the same value in MakerApple key 17.
  static func contentIdentifierItem(_ identifier: String) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = .quickTimeMetadataContentIdentifier
    item.value = identifier as NSString
    item.dataType = kCMMetadataBaseDataType_UTF8 as String
    return item
  }

  private static let stillImageTimeIdentifier = "mdta/com.apple.quicktime.still-image-time"

  private static func stillImageTimeInput() throws -> AVAssetWriterInput {
    let spec: [CFString: Any] = [
      kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: stillImageTimeIdentifier,
      kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: kCMMetadataBaseDataType_SInt8,
    ]
    var description: CMFormatDescription?
    guard CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
      allocator: kCFAllocatorDefault,
      metadataType: kCMMetadataFormatType_Boxed,
      metadataSpecifications: [spec] as CFArray,
      formatDescriptionOut: &description
    ) == noErr, let description else { throw PrismLivePhotoFailure.encodeFailed }
    let input = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: description)
    input.expectsMediaDataInRealTime = false
    return input
  }

  private static func stillImageTimeItem() -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = AVMetadataIdentifier(rawValue: stillImageTimeIdentifier)
    item.value = NSNumber(value: Int8(0))
    item.dataType = kCMMetadataBaseDataType_SInt8 as String
    return item
  }

  static func waitUntilReady(_ input: AVAssetWriterInput, writer: AVAssetWriter) async throws {
    while true {
      try Task.checkCancellation()
      guard writer.status == .writing else { throw PrismLivePhotoFailure.encodeFailed }
      if input.isReadyForMoreMediaData { return }
      try await Task.sleep(nanoseconds: 2_000_000)
    }
  }

  static func finishWriting(
    _ writer: AVAssetWriter,
    start: (AVAssetWriter) -> Void = { $0.finishWriting(completionHandler: {}) }
  ) async throws {
    start(writer)
    do {
      while writer.status == .writing {
        try Task.checkCancellation()
        try await Task.sleep(nanoseconds: 2_000_000)
      }
      try Task.checkCancellation()
    } catch {
      if writer.status == .writing { writer.cancelWriting() }
      throw error
    }
  }

  /// HEIC with the content identifier in MakerApple key 17. JPEG when this device has no HEIC encoder.
  static func writeKeyPhoto(
    from buffer: CVPixelBuffer, to url: URL, identifier: String,
    types: [UTType] = [.heic, .jpeg]
  ) throws -> URL {
    guard let image = cgImage(from: buffer) else { throw PrismLivePhotoFailure.renderFailed }
    let properties: [CFString: Any] = [
      kCGImagePropertyMakerAppleDictionary: ["17": identifier],
      kCGImageDestinationLossyCompressionQuality: 0.92,
      kCGImagePropertyOrientation: 1,
    ]
    for type in types {
      let target = type == .heic ? url : url.deletingPathExtension().appendingPathExtension("jpg")
      guard let destination = CGImageDestinationCreateWithURL(target as CFURL, type.identifier as CFString, 1, nil)
      else { continue }
      CGImageDestinationAddImage(destination, image, properties as CFDictionary)
      if CGImageDestinationFinalize(destination) {
        return target
      }
    }
    throw PrismLivePhotoFailure.renderFailed
  }

  private static func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer),
      let context = CGContext(
        data: base,
        width: CVPixelBufferGetWidth(buffer),
        height: CVPixelBufferGetHeight(buffer),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
      )
    else { return nil }
    return context.makeImage()
  }

  /// Runs [work] and cancels it after [milliseconds]. Saving is not inside, so a save never times out half done.
  private static func withTimeout<T: Sendable>(
    milliseconds: Int64,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask { try await work() }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(max(1, milliseconds)) * 1_000_000)
        throw PrismLivePhotoFailure.timedOut
      }
      defer { group.cancelAll() }
      guard let first = try await group.next() else { throw CancellationError() }
      return first
    }
  }
}

private extension Task where Failure == Error {
  /// Waits for a detached task and passes a cancel through to it.
  func valueCancellingOnCancel() async throws -> Success {
    try await withTaskCancellationHandler { try await value } onCancel: { cancel() }
  }
}

/// Photos access, the paired save and the read-back.
enum PrismLivePhotoLibrary {
  static func requestAddAccess() async -> PHAuthorizationStatus {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    guard status == .notDetermined else { return status }
    return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
  }

  private final class Placeholder: @unchecked Sendable {
    var localIdentifier: String?
  }

  /// Saves both files as one asset and returns its local identifier.
  static func save(_ files: PrismLivePhotoFiles) async throws -> String {
    let placeholder = Placeholder()
    do {
      try await PHPhotoLibrary.shared().performChanges { @Sendable in
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, fileURL: files.photo, options: nil)
        request.addResource(with: .pairedVideo, fileURL: files.video, options: nil)
        placeholder.localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
      }
    } catch {
      throw PrismLivePhotoFailure.saveFailed
    }
    guard let identifier = placeholder.localIdentifier else { throw PrismLivePhotoFailure.saveFailed }
    return identifier
  }

  /// True or false when the app may read the library. Nil with add-only access, which cannot fetch assets.
  static func isLivePhoto(localIdentifier: String) -> Bool? {
    switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
    case .authorized, .limited:
      guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
      else { return nil }
      return asset.mediaSubtypes.contains(.photoLive)
    default:
      return nil
    }
  }
}
