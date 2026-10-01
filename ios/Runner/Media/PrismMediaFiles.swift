import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PrismImageFile: Sendable {
  let url: URL
  let fileExtension: String
  let uniformTypeIdentifier: String
  let originalFilename: String
  let isTemporary: Bool
}

actor PrismMediaFiles {
  static let maximumImageBytes = 100 * 1024 * 1024
  private static let downloadSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 600
    return URLSession(configuration: configuration)
  }()
  private let downloadsDirectory: URL?
  private let download: @Sendable (URLRequest) async throws -> (URL, URLResponse)

  init(
    downloadsDirectory: URL? = nil,
    download: @escaping @Sendable (URLRequest) async throws -> (URL, URLResponse) = PrismMediaFiles.downloadImage
  ) {
    self.downloadsDirectory = downloadsDirectory
    self.download = download
  }

  nonisolated static func validateFilename(_ filename: String) throws {
    guard !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      filename.utf8.count <= 200, !filename.hasPrefix("."),
      !filename.contains("/"), !filename.contains("\\"),
      filename.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
    else {
      throw PrismMediaError.invalidFilename
    }
  }

  func resolve(link: String, isLocalFile: Bool) async throws -> PrismImageFile {
    let source = isLocalFile ? try Self.localURL(link) : try Self.networkURL(link)
    let url = isLocalFile ? source : try await downloadedURL(source)
    do {
      return try normalizedImage(at: url, nameSource: source, isTemporary: !isLocalFile)
    } catch {
      if !isLocalFile { try? FileManager.default.removeItem(at: url) }
      throw error
    }
  }

  private nonisolated static func localURL(_ link: String) throws -> URL {
    let url: URL
    if link.hasPrefix("file:") {
      guard let fileURL = URL(string: link), fileURL.isFileURL,
        fileURL.host == nil || fileURL.host == "" || fileURL.host == "localhost"
      else { throw PrismMediaError.invalidURL }
      url = fileURL
    } else {
      guard link.hasPrefix("/") else { throw PrismMediaError.invalidURL }
      url = URL(fileURLWithPath: link)
    }
    guard FileManager.default.fileExists(atPath: url.path) else { throw PrismMediaError.localFileMissing }
    return url
  }

  private func downloadedURL(_ source: URL) async throws -> URL {
    var request = URLRequest(url: source)
    request.timeoutInterval = 30
    let url: URL
    let response: URLResponse
    do {
      (url, response) = try await download(request)
    } catch {
      throw PrismMediaError.networkFailed(error.localizedDescription)
    }
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      try? FileManager.default.removeItem(at: url)
      throw PrismMediaError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    return url
  }

  private func imageType(at url: URL) throws -> UTType {
    let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard size.isRegularFile == true else { throw PrismMediaError.invalidImage }
    guard (size.fileSize ?? 0) > 0 else { throw PrismMediaError.emptyPayload }
    guard (size.fileSize ?? 0) <= Self.maximumImageBytes else { throw PrismMediaError.imageTooLarge }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      CGImageSourceGetStatus(source) == .statusComplete,
      let identifier = CGImageSourceGetType(source),
      let type = UTType(identifier as String), type.conforms(to: .image),
      CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: 1,
        kCGImageSourceShouldCache: false
      ] as CFDictionary) != nil
    else { throw PrismMediaError.invalidImage }
    return type
  }

  private func normalizedImage(at url: URL, nameSource: URL, isTemporary: Bool) throws -> PrismImageFile {
    let type = try imageType(at: url)
    guard let fileExtension = type.preferredFilenameExtension else { throw PrismMediaError.invalidImage }
    let stem = nameSource.deletingPathExtension().lastPathComponent
    let originalFilename = "\(stem.isEmpty || stem == "/" ? "Prism" : stem).\(fileExtension)"
    if UTType(filenameExtension: url.pathExtension) != type {
      let normalized = FileManager.default.temporaryDirectory
        .appendingPathComponent("PrismImage-\(UUID().uuidString).\(fileExtension)")
      do {
        if isTemporary {
          try FileManager.default.moveItem(at: url, to: normalized)
        } else {
          try FileManager.default.copyItem(at: url, to: normalized)
        }
      } catch {
        try? FileManager.default.removeItem(at: normalized)
        throw error
      }
      return PrismImageFile(
        url: normalized, fileExtension: fileExtension, uniformTypeIdentifier: type.identifier,
        originalFilename: originalFilename, isTemporary: true
      )
    }
    return PrismImageFile(
      url: url, fileExtension: fileExtension, uniformTypeIdentifier: type.identifier,
      originalFilename: originalFilename, isTemporary: isTemporary
    )
  }

  nonisolated static func networkURL(_ link: String) throws -> URL {
    guard let url = URL(string: link), let scheme = url.scheme?.lowercased(),
      ["https", "http"].contains(scheme), let host = url.host, !host.isEmpty,
      url.user == nil, url.password == nil
    else { throw PrismMediaError.invalidURL }
    return url
  }

  nonisolated static func downloadImage(_ request: URLRequest) async throws -> (URL, URLResponse) {
    try await downloadSession.download(for: request, delegate: PrismDownloadDelegate())
  }

  func removeTemporarySource(_ image: PrismImageFile) {
    if image.isTemporary { try? FileManager.default.removeItem(at: image.url) }
  }

  func stage(image: PrismImageFile, filename: String) throws -> URL {
    guard "\(filename).\(image.fileExtension)".utf8.count <= 255 else { throw PrismMediaError.invalidFilename }
    let directory = try directory()
    let staged = directory.appendingPathComponent(".\(UUID().uuidString).\(image.fileExtension)")
    do {
      try FileManager.default.copyItem(at: image.url, to: staged)
      return staged
    } catch {
      try? FileManager.default.removeItem(at: staged)
      throw error
    }
  }

  func commit(staged: URL, filename: String) throws -> URL {
    let directory = try directory()
    var destination = directory.appendingPathComponent("\(filename).\(staged.pathExtension)")
    var suffix = 1
    while FileManager.default.fileExists(atPath: destination.path) {
      destination = directory.appendingPathComponent("\(filename) (\(suffix)).\(staged.pathExtension)")
      suffix += 1
    }
    try FileManager.default.moveItem(at: staged, to: destination)
    return destination
  }

  func discard(staged: URL) {
    try? FileManager.default.removeItem(at: staged)
  }

  func list() throws -> [URL] {
    try FileManager.default.contentsOfDirectory(
      at: directory(), includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: .skipsHiddenFiles
    ).filter {
      let properties = try $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      return properties.isRegularFile == true && properties.isSymbolicLink != true
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  func clear() throws -> Bool {
    let files = try list()
    for file in files { try FileManager.default.removeItem(at: file) }
    return !files.isEmpty
  }

  private func directory() throws -> URL {
    let directory: URL
    if let downloadsDirectory {
      directory = downloadsDirectory
    } else {
      directory = try FileManager.default.url(
        for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
      ).appendingPathComponent("PrismDownloads", isDirectory: true)
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}

private final class PrismDownloadDelegate: NSObject, URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}

  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
  ) {
    if totalBytesWritten > PrismMediaFiles.maximumImageBytes ||
      totalBytesExpectedToWrite > PrismMediaFiles.maximumImageBytes {
      downloadTask.cancel()
    }
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    guard let url = request.url, (try? PrismMediaFiles.networkURL(url.absoluteString)) != nil,
      !(response.url?.scheme?.lowercased() == "https" && url.scheme?.lowercased() == "http")
    else {
      completionHandler(nil)
      return
    }
    completionHandler(request)
  }
}

enum PrismMediaError: Error, LocalizedError {
  case invalidURL, invalidFilename, invalidImage, emptyPayload, imageTooLarge, localFileMissing
  case networkFailed(String), httpStatus(Int)
  case photoPermissionDenied, photoPermissionRestricted, photoPermissionUnknown, photoWriteFailed(String)

  var code: String {
    switch self {
    case .invalidURL: "INVALID_URL"
    case .invalidFilename: "INVALID_FILENAME"
    case .invalidImage: "INVALID_IMAGE"
    case .emptyPayload: "EMPTY_PAYLOAD"
    case .imageTooLarge: "IMAGE_TOO_LARGE"
    case .localFileMissing: "LOCAL_FILE_MISSING"
    case .networkFailed: "NETWORK_FAILED"
    case .httpStatus: "HTTP_STATUS_ERROR"
    case .photoPermissionDenied: "PHOTO_PERMISSION_DENIED"
    case .photoPermissionRestricted: "PHOTO_PERMISSION_RESTRICTED"
    case .photoPermissionUnknown: "PHOTO_PERMISSION_UNKNOWN"
    case .photoWriteFailed: "PHOTO_LIBRARY_WRITE_FAILED"
    }
  }

  var errorDescription: String? {
    switch self {
    case .invalidURL: "Invalid media URL."
    case .invalidFilename: "Invalid download filename."
    case .invalidImage: "The downloaded file is not a supported image."
    case .emptyPayload: "Downloaded file is empty."
    case .imageTooLarge: "Images must be smaller than 100 MiB."
    case .localFileMissing: "Local image file not found."
    case .networkFailed(let message): "Network download failed: \(message)"
    case .httpStatus(let code): "Download failed with HTTP status \(code)."
    case .photoPermissionDenied: "Allow Prism to add photos in Settings to save wallpapers."
    case .photoPermissionRestricted: "Photo Library permission restricted."
    case .photoPermissionUnknown: "Photo Library permission not determined."
    case .photoWriteFailed(let message): "Saving to Photos failed: \(message)"
    }
  }
}
