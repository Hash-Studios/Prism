import Foundation
import Photos

final class PrismMediaHostApiImpl: PrismMediaHostApi {
  private let workerQueue = DispatchQueue(label: "com.hash.prism.media-api", qos: .userInitiated)

  func saveMedia(request: SaveMediaRequest) throws -> OperationResult {
    return performBlocking {
      do {
        let data = try self.resolveImageData(link: request.link, isLocalFile: request.isLocalFile)
        try self.saveToPhotoLibrary(data: data)
        return OperationResult(success: true, errorCode: nil, message: nil)
      } catch let error as PrismMediaSaveError {
        return OperationResult(success: false, errorCode: error.code, message: error.message)
      } catch {
        return OperationResult(success: false, errorCode: "EXCEPTION", message: error.localizedDescription)
      }
    }
  }

  func enqueueDownload(request: DownloadRequest) throws -> OperationResult {
    return performBlocking {
      do {
        let data = try self.resolveImageData(link: request.link, isLocalFile: false)
        let ext = URL(string: request.link)?.pathExtension.lowercased() ?? ""
        let resolvedExt = ["jpg", "jpeg", "png", "webp", "gif"].contains(ext) ? ext : "jpg"
        let dir = try self.downloadsDirectory()
        let filename = "\(request.filenameWithoutExtension).\(resolvedExt)"
        let dest = dir.appendingPathComponent(filename)
        try data.write(to: dest, options: .atomic)
        return OperationResult(success: true, errorCode: nil, message: dest.path)
      } catch let error as PrismMediaSaveError {
        return OperationResult(success: false, errorCode: error.code, message: error.message)
      } catch {
        return OperationResult(success: false, errorCode: "EXCEPTION", message: error.localizedDescription)
      }
    }
  }

  func listDownloads() throws -> DownloadItemsResult {
    do {
      let dir = try downloadsDirectory()
      let contents = try FileManager.default.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: .skipsHiddenFiles
      )
      let paths = contents
        .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        .map { $0.path }
      return DownloadItemsResult(success: true, items: paths, errorCode: nil, message: nil)
    } catch {
      return DownloadItemsResult(success: false, items: [], errorCode: "LIST_FAILED", message: error.localizedDescription)
    }
  }

  func clearDownloads() throws -> OperationResult {
    do {
      let dir = try downloadsDirectory()
      let contents = try FileManager.default.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
      )
      guard !contents.isEmpty else {
        return OperationResult(success: false, errorCode: "NO_DOWNLOADS", message: "No downloads found.")
      }
      for file in contents {
        try FileManager.default.removeItem(at: file)
      }
      return OperationResult(success: true, errorCode: nil, message: nil)
    } catch {
      return OperationResult(success: false, errorCode: "CLEAR_FAILED", message: error.localizedDescription)
    }
  }

  private func downloadsDirectory() throws -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("PrismDownloads", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private func performBlocking(_ task: @escaping () -> OperationResult) -> OperationResult {
    let semaphore = DispatchSemaphore(value: 0)
    var result = OperationResult(success: false, errorCode: "UNKNOWN", message: "Unknown error")

    workerQueue.async {
      result = task()
      semaphore.signal()
    }

    semaphore.wait()
    return result
  }

  private func resolveImageData(link: String, isLocalFile: Bool) throws -> Data {
    if isLocalFile || isLikelyLocalPath(link) {
      let normalizedPath = normalizeLocalPath(link)
      guard FileManager.default.fileExists(atPath: normalizedPath) else {
        throw PrismMediaSaveError.localFileMissing(path: normalizedPath)
      }
      do {
        return try Data(contentsOf: URL(fileURLWithPath: normalizedPath))
      } catch {
        throw PrismMediaSaveError.localReadFailed(path: normalizedPath, underlying: error)
      }
    }

    guard let url = URL(string: link), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
      throw PrismMediaSaveError.invalidUrl(link: link)
    }

    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 30
    let session = URLSession(configuration: config)

    let semaphore = DispatchSemaphore(value: 0)
    var fetchedData: Data?
    var fetchError: Error?
    var statusCode: Int?

    let task = session.dataTask(with: url) { data, response, error in
      fetchedData = data
      fetchError = error
      statusCode = (response as? HTTPURLResponse)?.statusCode
      semaphore.signal()
    }
    task.resume()
    semaphore.wait()
    session.invalidateAndCancel()

    if let fetchError = fetchError {
      throw PrismMediaSaveError.networkFailed(underlying: fetchError)
    }

    if let statusCode = statusCode, !(200...299).contains(statusCode) {
      throw PrismMediaSaveError.httpStatus(code: statusCode)
    }

    guard let data = fetchedData, !data.isEmpty else {
      throw PrismMediaSaveError.emptyPayload
    }

    return data
  }

  private func saveToPhotoLibrary(data: Data) throws {
    try ensurePhotoPermission()

    let semaphore = DispatchSemaphore(value: 0)
    var saveError: Error?

    PHPhotoLibrary.shared().performChanges(
      {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: data, options: nil)
      },
      completionHandler: { success, error in
        if !success {
          saveError = error ?? PrismMediaSaveError.saveFailed
        }
        semaphore.signal()
      }
    )

    semaphore.wait()

    if let saveError = saveError {
      throw PrismMediaSaveError.photoLibraryWriteFailed(underlying: saveError)
    }
  }

  private func ensurePhotoPermission() throws {
    if #available(iOS 14, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      switch status {
      case .authorized, .limited:
        return
      case .denied:
        throw PrismMediaSaveError.permissionDenied
      case .restricted:
        throw PrismMediaSaveError.permissionRestricted
      case .notDetermined:
        let semaphore = DispatchSemaphore(value: 0)
        var resolvedStatus: PHAuthorizationStatus = .notDetermined
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
          resolvedStatus = newStatus
          semaphore.signal()
        }
        semaphore.wait()
        switch resolvedStatus {
        case .authorized, .limited:
          return
        case .denied:
          throw PrismMediaSaveError.permissionDenied
        case .restricted:
          throw PrismMediaSaveError.permissionRestricted
        case .notDetermined:
          throw PrismMediaSaveError.permissionUnknown
        @unknown default:
          throw PrismMediaSaveError.permissionUnknown
        }
      @unknown default:
        throw PrismMediaSaveError.permissionUnknown
      }
    } else {
      let status = PHPhotoLibrary.authorizationStatus()
      switch status {
      case .authorized:
        return
      case .denied:
        throw PrismMediaSaveError.permissionDenied
      case .restricted:
        throw PrismMediaSaveError.permissionRestricted
      case .notDetermined:
        let semaphore = DispatchSemaphore(value: 0)
        var resolvedStatus: PHAuthorizationStatus = .notDetermined
        PHPhotoLibrary.requestAuthorization { newStatus in
          resolvedStatus = newStatus
          semaphore.signal()
        }
        semaphore.wait()
        if resolvedStatus == .authorized {
          return
        }
        if resolvedStatus == .denied {
          throw PrismMediaSaveError.permissionDenied
        }
        if resolvedStatus == .restricted {
          throw PrismMediaSaveError.permissionRestricted
        }
        throw PrismMediaSaveError.permissionUnknown
      case .limited:
        return
      @unknown default:
        throw PrismMediaSaveError.permissionUnknown
      }
    }
  }

  private func isLikelyLocalPath(_ link: String) -> Bool {
    if link.hasPrefix("/") || link.hasPrefix("file://") {
      return true
    }
    if URL(string: link)?.scheme == nil {
      return true
    }
    return false
  }

  private func normalizeLocalPath(_ link: String) -> String {
    if link.hasPrefix("file://"), let url = URL(string: link) {
      return url.path
    }
    return link
  }
}

private enum PrismMediaSaveError: Error {
  case invalidUrl(link: String)
  case networkFailed(underlying: Error)
  case httpStatus(code: Int)
  case emptyPayload
  case localFileMissing(path: String)
  case localReadFailed(path: String, underlying: Error)
  case permissionDenied
  case permissionRestricted
  case permissionUnknown
  case saveFailed
  case photoLibraryWriteFailed(underlying: Error)

  var code: String {
    switch self {
    case .invalidUrl:
      return "INVALID_URL"
    case .networkFailed:
      return "NETWORK_FAILED"
    case .httpStatus:
      return "HTTP_STATUS_ERROR"
    case .emptyPayload:
      return "EMPTY_PAYLOAD"
    case .localFileMissing:
      return "LOCAL_FILE_MISSING"
    case .localReadFailed:
      return "LOCAL_READ_FAILED"
    case .permissionDenied:
      return "PHOTO_PERMISSION_DENIED"
    case .permissionRestricted:
      return "PHOTO_PERMISSION_RESTRICTED"
    case .permissionUnknown:
      return "PHOTO_PERMISSION_UNKNOWN"
    case .saveFailed:
      return "PHOTO_SAVE_FAILED"
    case .photoLibraryWriteFailed:
      return "PHOTO_LIBRARY_WRITE_FAILED"
    }
  }

  var message: String {
    switch self {
    case .invalidUrl(let link):
      return "Invalid media URL: \(link)"
    case .networkFailed(let underlying):
      return "Network download failed: \(underlying.localizedDescription)"
    case .httpStatus(let code):
      return "Download failed with HTTP status \(code)"
    case .emptyPayload:
      return "Downloaded file is empty."
    case .localFileMissing(let path):
      return "Local file not found at path: \(path)"
    case .localReadFailed(let path, let underlying):
      return "Failed reading local file \(path): \(underlying.localizedDescription)"
    case .permissionDenied:
      return "Photo Library permission denied."
    case .permissionRestricted:
      return "Photo Library permission restricted."
    case .permissionUnknown:
      return "Photo Library permission not determined."
    case .saveFailed:
      return "Failed to save media to Photos."
    case .photoLibraryWriteFailed(let underlying):
      return "Saving to Photos failed: \(underlying.localizedDescription)"
    }
  }
}
