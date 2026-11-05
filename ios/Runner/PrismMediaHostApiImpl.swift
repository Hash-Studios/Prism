import Foundation
import Photos
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

  private static func saveToPhotoLibrary(image: PrismImageFile, album: String?) async throws {
    guard let album, !album.trimmingCharacters(in: .whitespaces).isEmpty else {
      try await addToPhotoLibrary(image: image)
      return
    }
    var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .notDetermined {
      status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    guard status == .authorized || status == .limited else {
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
