import Foundation
import Photos
import Testing

@testable import Runner

@MainActor
struct RunnerTests {
  @Test func downloadSavesRealImageAndReadableCacheAfterPhotosCompletes() async throws {
    let fixture = try MediaFixture()
    let imageBytes = try Data(contentsOf: fixture.source)
    var saved: [Data] = []
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads, download: fixture.downloader())
    let api = PrismMediaHostApiImpl(files: files, savePhoto: { saved.append(try Data(contentsOf: $0.url)) })

    let result = try await download(api)
    #expect(result.success)
    #expect(saved == [imageBytes])
    let path = try #require(result.message)
    #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == imageBytes)
    #expect(URL(fileURLWithPath: path).lastPathComponent == "prism-test.png")
  }

  @Test func photosDenialLeavesNoCachedDownload() async throws {
    let fixture = try MediaFixture()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads, download: fixture.downloader())
    let api = PrismMediaHostApiImpl(files: files, savePhoto: { _ in throw PrismMediaError.photoPermissionDenied })

    let result = try await download(api)
    #expect(!result.success)
    #expect(result.errorCode == "PHOTO_PERMISSION_DENIED")
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.downloads.path).isEmpty)
  }

  @Test func malformedFilenameFailsBeforePhotos() async throws {
    let fixture = try MediaFixture()
    var photosCalled = false
    let api = PrismMediaHostApiImpl(
      files: PrismMediaFiles(downloadsDirectory: fixture.downloads, download: fixture.downloader()),
      savePhoto: { _ in photosCalled = true }
    )
    let result = try await withCheckedThrowingContinuation { continuation in
      let request = DownloadRequest(link: "https://example.com/image", filenameWithoutExtension: "../escape")
      api.enqueueDownload(request: request) {
        continuation.resume(with: $0)
      }
    }
    #expect(!result.success)
    #expect(result.errorCode == "INVALID_FILENAME")
    #expect(!photosCalled)
    #expect(!FileManager.default.fileExists(atPath: fixture.downloads.path))
  }

  @Test func localSourceStillExistsWhenSaveMediaCompletes() async throws {
    let fixture = try MediaFixture()
    var photosCalled = false
    let api = PrismMediaHostApiImpl(savePhoto: { image in
      #expect(FileManager.default.fileExists(atPath: image.url.path))
      #expect(image.uniformTypeIdentifier == "public.png")
      photosCalled = true
    })
    let result = try await withCheckedThrowingContinuation { continuation in
      let request = SaveMediaRequest(link: fixture.source.absoluteString, isLocalFile: true, kind: .wallpaper)
      api.saveMedia(request: request) {
        #expect(Thread.isMainThread)
        continuation.resume(with: $0)
      }
    }
    #expect(result.success)
    #expect(photosCalled)
    #expect(FileManager.default.fileExists(atPath: fixture.source.path))
  }

  @Test func clearWaitsForPendingPhotoSaveThenRemovesItsDownload() async throws {
    let fixture = try MediaFixture()
    let photos = PausedPhotos()
    let files = PrismMediaFiles(downloadsDirectory: fixture.downloads, download: fixture.downloader())
    let api = PrismMediaHostApiImpl(files: files, savePhoto: photos.save)
    var callbacks: [String] = []

    let downloadTask = Task { try await download(api, onComplete: { callbacks.append("download") }) }
    await photos.waitUntilStarted()
    let clearTask = Task {
      try await withCheckedThrowingContinuation { continuation in
        api.clearDownloads {
          #expect(Thread.isMainThread)
          callbacks.append("clear")
          continuation.resume(with: $0)
        }
      }
    }
    await Task.yield()
    #expect(callbacks.isEmpty)
    photos.finish()
    #expect(try await downloadTask.value.success)
    #expect(try await clearTask.value.success)
    #expect(callbacks == ["download", "clear"])
    #expect(try await files.list().isEmpty)
  }

  @Test func completedDownloadQueueReleasesItsOwner() async throws {
    let fixture = try MediaFixture()
    var api: PrismMediaHostApiImpl? = PrismMediaHostApiImpl(
      files: PrismMediaFiles(downloadsDirectory: fixture.downloads, download: fixture.downloader()),
      savePhoto: { _ in }
    )
    weak let owner = api
    #expect(try await download(#require(api)).success)
    api = nil
    await Task.yield()
    #expect(owner == nil)
  }

  #if targetEnvironment(simulator)
  @Test func realPhotoLibraryAcceptsMislabelledPngAndCompletesBeforeReply() async throws {
    try #require(PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized)
    let started = Date().addingTimeInterval(-1)
    let fixture = try MediaFixture()
    let stem = "PrismPhotosTest-\(UUID().uuidString)"
    let filename = "\(stem).png"
    let source = fixture.root.appendingPathComponent("\(stem).tmp")
    try FileManager.default.copyItem(at: fixture.source, to: source)
    let api = PrismMediaHostApiImpl()
    var callbacks = 0
    let outcome: Result<OperationResult, Error> = await withCheckedContinuation { continuation in
      api.saveMedia(request: SaveMediaRequest(link: source.path, isLocalFile: true, kind: .wallpaper)) {
        #expect(Thread.isMainThread)
        callbacks += 1
        continuation.resume(returning: $0)
      }
    }
    let result = try outcome.get()
    try #require(result.success, "Save failed: \(result.message ?? "unknown")")
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "creationDate >= %@", started as NSDate)
    let assets = PHAsset.fetchAssets(with: .image, options: options)
    let identifiers = (0..<assets.count).compactMap { index -> String? in
      let asset = assets.object(at: index)
      return PHAssetResource.assetResources(for: asset).contains { $0.originalFilename == filename }
        ? asset.localIdentifier : nil
    }
    #expect(identifiers.count == 1)
    if !identifiers.isEmpty {
      try await PHPhotoLibrary.shared().performChanges { @Sendable in
        PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil))
      }
    }
    #expect(PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil).count == 0)
    #expect(callbacks == 1)
    #expect(FileManager.default.fileExists(atPath: source.path))
  }
  #endif

  private func download(
    _ api: PrismMediaHostApiImpl, onComplete: @escaping @MainActor () -> Void = {}
  ) async throws -> OperationResult {
    try await withCheckedThrowingContinuation { continuation in
      let request = DownloadRequest(link: "https://example.com/image.jpg", filenameWithoutExtension: "prism-test")
      api.enqueueDownload(request: request) {
        #expect(Thread.isMainThread)
        onComplete()
        continuation.resume(with: $0)
      }
    }
  }
}

@MainActor
private final class PausedPhotos {
  private var started = false
  private var startedContinuation: CheckedContinuation<Void, Never>?
  private var finishContinuation: CheckedContinuation<Void, Never>?

  func save(_ image: PrismImageFile) async throws {
    #expect(FileManager.default.fileExists(atPath: image.url.path))
    started = true
    startedContinuation?.resume()
    startedContinuation = nil
    await withCheckedContinuation { finishContinuation = $0 }
  }

  func waitUntilStarted() async {
    if !started { await withCheckedContinuation { startedContinuation = $0 } }
  }

  func finish() {
    finishContinuation?.resume()
    finishContinuation = nil
  }
}
