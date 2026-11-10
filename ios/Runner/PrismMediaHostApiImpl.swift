import AVFoundation
import Foundation
import Photos
import UIKit
import UniformTypeIdentifiers

@MainActor
final class PrismMediaHostApiImpl: @preconcurrency PrismMediaHostApi {
  private let files: PrismMediaFiles
  private let savePhoto: @MainActor (PrismImageFile, String?) async throws -> Void
  private var downloadsTail: Task<Void, Never>?
  private var downloadQueueGeneration: UInt64 = 0

  init(
    files: PrismMediaFiles = PrismMediaFiles(),
    savePhoto: @escaping @MainActor (PrismImageFile, String?) async throws -> Void = PrismMediaHostApiImpl.saveToPhotoLibrary
  ) {
    self.files = files
    self.savePhoto = savePhoto
  }

  func saveMedia(request: SaveMediaRequest, completion: @escaping (Result<OperationResult, Error>) -> Void) {
    Task {
      do {
        let image = try await files.resolve(link: request.link, isLocalFile: request.isLocalFile)
        do {
          try await savePhoto(image, nil)
          await files.removeTemporarySource(image)
          completion(.success(OperationResult(success: true)))
        } catch {
          await files.removeTemporarySource(image)
          throw error
        }
      } catch {
        completion(.success(failure(error)))
      }
    }
  }

  func enqueueDownload(request: DownloadRequest, completion: @escaping (Result<OperationResult, Error>) -> Void) {
    queueDownloadOperation { [self] in
      do {
        try PrismMediaFiles.validateFilename(request.filenameWithoutExtension)
        let image = try await files.resolve(link: request.link, isLocalFile: request.isLocalFile)
        let staged: URL
        do {
          staged = try await files.stage(image: image, filename: request.filenameWithoutExtension)
          await files.removeTemporarySource(image)
        } catch {
          await files.removeTemporarySource(image)
          throw error
        }
        do {
          try await savePhoto(PrismImageFile(
            url: staged, fileExtension: image.fileExtension,
            uniformTypeIdentifier: image.uniformTypeIdentifier,
            originalFilename: "\(request.filenameWithoutExtension).\(image.fileExtension)", isTemporary: false
          ), request.album)
          let destination = try await files.commit(staged: staged, filename: request.filenameWithoutExtension)
          completion(.success(OperationResult(success: true, message: destination.path)))
        } catch {
          await files.discard(staged: staged)
          throw error
        }
      } catch {
        completion(.success(failure(error)))
      }
    }
  }

  func prepareAlbumSave(album: String, completion: @escaping (Result<OperationResult, Error>) -> Void) {
    Task {
      var readWrite = PHPhotoLibrary.authorizationStatus(for: .readWrite)
      if readWrite == .notDetermined {
        readWrite = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
      }
      if readWrite == .authorized || readWrite == .limited {
        completion(.success(OperationResult(success: true)))
        return
      }
      var addOnly = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      if addOnly == .notDetermined {
        addOnly = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      }
      switch addOnly {
      case .authorized, .limited:
        completion(.success(OperationResult(success: true)))
      case .denied:
        completion(.success(OperationResult(success: false, errorCode: "PHOTO_PERMISSION_DENIED")))
      case .restricted:
        completion(.success(OperationResult(success: false, errorCode: "PHOTO_PERMISSION_RESTRICTED")))
      default:
        completion(.success(OperationResult(success: false, errorCode: "PHOTO_PERMISSION_UNKNOWN")))
      }
    }
  }

  func listDownloads(completion: @escaping (Result<DownloadItemsResult, Error>) -> Void) {
    queueDownloadOperation { [self] in
      do {
        let paths = try await files.list().map(\.path)
        completion(.success(DownloadItemsResult(success: true, items: paths)))
      } catch {
        completion(.success(DownloadItemsResult(
          success: false, items: [], errorCode: "LIST_FAILED"
        )))
      }
    }
  }

  func clearDownloads(completion: @escaping (Result<OperationResult, Error>) -> Void) {
    queueDownloadOperation { [self] in
      do {
        let removed = try await files.clear()
        completion(.success(removed
          ? OperationResult(success: true)
          : OperationResult(success: false, errorCode: "NO_DOWNLOADS")))
      } catch {
        completion(.success(OperationResult(
          success: false, errorCode: "CLEAR_FAILED"
        )))
      }
    }
  }

  func deleteDownload(path: String, completion: @escaping (Result<OperationResult, Error>) -> Void) {
    queueDownloadOperation { [self] in
      do {
        let removed = try await files.delete(path: path)
        completion(.success(removed
          ? OperationResult(success: true)
          : OperationResult(success: false, errorCode: "NOT_FOUND")))
      } catch {
        completion(.success(OperationResult(
          success: false, errorCode: "DELETE_FAILED"
        )))
      }
    }
  }

  func extractVideoFrames(
    path: String, timesMs: [Int64], maxEdge: Int64, quality: Int64,
    completion: @escaping (Result<[String], Error>) -> Void
  ) {
    Task {
      let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[String], Error>, Never>) in
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let paths = try Self.writeVideoFrames(path: path, timesMs: timesMs, maxEdge: maxEdge, quality: quality)
            continuation.resume(returning: .success(paths))
          } catch {
            continuation.resume(returning: .failure(PigeonError(
              code: "frame-failed", message: error.localizedDescription, details: nil
            )))
          }
        }
      }
      completion(result)
    }
  }

  func saveVideo(path: String, completion: @escaping (Result<OperationResult, Error>) -> Void) {
    Task {
      var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      if status == .notDetermined {
        status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      }
      guard status == .authorized || status == .limited else {
        completion(.success(OperationResult(success: false, errorCode: "permission-denied", message: nil)))
        return
      }
      let url = URL(fileURLWithPath: path)
      do {
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
        completion(.success(OperationResult(success: true)))
      } catch {
        completion(.success(OperationResult(
          success: false, errorCode: "save-failed", message: error.localizedDescription
        )))
      }
    }
  }

  nonisolated private static func writeVideoFrames(
    path: String, timesMs: [Int64], maxEdge: Int64, quality: Int64
  ) throws -> [String] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let durationSeconds = asset.duration.seconds
    guard durationSeconds.isFinite, durationSeconds > 0 else {
      throw PigeonError(code: "frame-failed", message: "Video has no duration", details: nil)
    }
    let durationMs = Int64(durationSeconds * 1000)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: CGFloat(maxEdge), height: CGFloat(maxEdge))
    generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
    generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
    let token = UUID().uuidString
    var paths: [String] = []
    for (index, ms) in timesMs.enumerated() {
      let clampedMs = min(max(ms, 0), max(durationMs - 1, 0))
      let cgImage = try generator.copyCGImage(at: CMTime(value: clampedMs, timescale: 1000), actualTime: nil)
      guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: CGFloat(quality) / 100) else {
        throw PigeonError(code: "frame-failed", message: "JPEG encoding failed", details: nil)
      }
      let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("prism_live_frame_\(token)_\(index).jpg")
      try data.write(to: url, options: .atomic)
      paths.append(url.path)
    }
    return paths
  }

  private func queueDownloadOperation(_ operation: @escaping @MainActor () async -> Void) {
    let previous = downloadsTail
    downloadQueueGeneration &+= 1
    let generation = downloadQueueGeneration
    downloadsTail = Task {
      await previous?.value
      await operation()
      if generation == downloadQueueGeneration { downloadsTail = nil }
    }
  }

  private func failure(_ error: Error) -> OperationResult {
    let mediaError = error as? PrismMediaError
    return OperationResult(
      success: false, errorCode: mediaError?.code ?? "EXCEPTION"
    )
  }

  nonisolated static func canManagePhotoAlbums(with status: PHAuthorizationStatus) -> Bool {
    status == .authorized
  }

  private static func saveToPhotoLibrary(image: PrismImageFile, album: String?) async throws {
    guard let album, !album.trimmingCharacters(in: .whitespaces).isEmpty else {
      try await addToPhotoLibrary(image: image)
      return
    }
    var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .notDetermined {
      status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    guard canManagePhotoAlbums(with: status) else {
      try await addToPhotoLibrary(image: image)
      return
    }
    let existingAlbumIdentifier = albumIdentifier(titled: album)
    do {
      try await PHPhotoLibrary.shared().performChanges { @Sendable in
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = image.originalFilename
        if #available(iOS 26, *) {
          options.contentType = UTType(image.uniformTypeIdentifier)
        } else {
          options.uniformTypeIdentifier = image.uniformTypeIdentifier
        }
        let creation = PHAssetCreationRequest.forAsset()
        creation.addResource(with: .photo, fileURL: image.url, options: options)
        guard let placeholder = creation.placeholderForCreatedAsset else { return }
        if let identifier = existingAlbumIdentifier,
           let existing = PHAssetCollection.fetchAssetCollections(
             withLocalIdentifiers: [identifier], options: nil
           ).firstObject {
          PHAssetCollectionChangeRequest(for: existing)?.addAssets([placeholder] as NSArray)
        } else {
          PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: album)
            .addAssets([placeholder] as NSArray)
        }
      }
    } catch {
      throw PrismMediaError.photoWriteFailed(error.localizedDescription)
    }
  }

  private static func albumIdentifier(titled title: String) -> String? {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "title = %@", title)
    return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
      .firstObject?.localIdentifier
  }

  private static func addToPhotoLibrary(image: PrismImageFile) async throws {
    var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    if status == .notDetermined {
      status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
    switch status {
    case .authorized, .limited:
      break
    case .denied:
      throw PrismMediaError.photoPermissionDenied
    case .restricted:
      throw PrismMediaError.photoPermissionRestricted
    case .notDetermined:
      throw PrismMediaError.photoPermissionUnknown
    @unknown default:
      throw PrismMediaError.photoPermissionUnknown
    }

    do {
      try await PHPhotoLibrary.shared().performChanges { @Sendable in
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = image.originalFilename
        if #available(iOS 26, *) {
          options.contentType = UTType(image.uniformTypeIdentifier)
        } else {
          options.uniformTypeIdentifier = image.uniformTypeIdentifier
        }
        PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: image.url, options: options)
      }
    } catch {
      throw PrismMediaError.photoWriteFailed(error.localizedDescription)
    }
  }
}
