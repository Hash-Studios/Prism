import Foundation

enum PrismShortcutLoadError: Error {
  case missingConfiguration
  case badResponse
  case missingField
}

enum PrismShortcutWallpaperLoader {
  static let maximumImageBytes = 40 * 1024 * 1024
  static let imageSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60
    return URLSession(configuration: configuration)
  }()
  static let metadataSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    configuration.timeoutIntervalForResource = 20
    return URLSession(configuration: configuration)
  }()

  static func wallOfTheDayImageURL() async throws -> URL {
    let retainedURL: URL?
    if let cached = UserDefaults.standard.string(forKey: "flutter.quick_tile.wotd.url"),
      let url = PrismShortcutFavourites.httpsURL(cached), localImageData(for: url) != nil
    {
      retainedURL = url
    } else {
      retainedURL = nil
    }
    return try await freshThenRetained(cachedURL: retainedURL) {
      let configuration = try firebaseConfiguration()
      let pointer = try await document(configuration, collection: "wall_of_the_day", id: "current")
      guard let wallID = PrismFirestoreREST.stringField("wallId", in: pointer) else {
        throw PrismShortcutLoadError.missingField
      }
      let wall = try await document(configuration, collection: "walls", id: wallID)
      guard let link = PrismFirestoreREST.stringField("wallpaper_url", in: wall),
        let url = PrismShortcutFavourites.httpsURL(link)
      else {
        throw PrismShortcutLoadError.missingField
      }
      return url
    }
  }

  static func freshThenRetained(
    cachedURL: URL?,
    fetchFresh: () async throws -> URL
  ) async throws -> URL {
    let fresh: Result<URL, Error>
    do {
      fresh = .success(try await fetchFresh())
    } catch {
      fresh = .failure(error)
    }
    return try PrismShortcutWallpaperFallback.resolve(fresh: fresh, retained: cachedURL)
  }

  static func imageData(from url: URL) async throws -> Data {
    if let local = localImageData(for: url) { return local }
    let (file, response) = try await imageSession.download(from: url)
    defer { try? FileManager.default.removeItem(at: file) }
    guard let http = response as? HTTPURLResponse, http.statusCode == 200,
      response.expectedContentLength <= Int64(maximumImageBytes)
    else {
      throw PrismShortcutLoadError.badResponse
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    guard let size = (attributes[.size] as? NSNumber)?.int64Value,
      size > 0, size <= Int64(maximumImageBytes)
    else {
      throw PrismShortcutLoadError.badResponse
    }
    try Task.checkCancellation()
    return try Data(contentsOf: file)
  }

  private static func localImageData(for url: URL) -> Data? {
    guard
      let raw = UserDefaults.standard.string(forKey: PrismShortcutFavourites.nativeAssetPathsKey),
      let paths = try? JSONDecoder().decode([String: String].self, from: Data(raw.utf8)),
      let relativePath = paths[url.absoluteString]
    else { return nil }
    let fileManager = FileManager.default
    guard
      let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return nil }
    let retainedRoot = support.appendingPathComponent("prism/offline/assets", isDirectory: true)
    let downloadsRoot = documents.appendingPathComponent("PrismDownloads", isDirectory: true)
    guard let file = PrismShortcutLocalFileResolver.resolve(
      path: relativePath,
      roots: [retainedRoot, downloadsRoot],
      maximumBytes: maximumImageBytes
    ) else { return nil }
    return try? Data(contentsOf: file)
  }

  private static func firebaseConfiguration() throws -> (projectID: String, apiKey: String) {
    guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
      let data = try? Data(contentsOf: url),
      let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
      let projectID = values["PROJECT_ID"] as? String, !projectID.isEmpty,
      let apiKey = values["API_KEY"] as? String, !apiKey.isEmpty
    else {
      throw PrismShortcutLoadError.missingConfiguration
    }
    return (projectID, apiKey)
  }

  private static func document(
    _ configuration: (projectID: String, apiKey: String),
    collection: String,
    id: String
  ) async throws -> Data {
    guard
      let url = PrismFirestoreREST.documentURL(
        projectID: configuration.projectID,
        apiKey: configuration.apiKey,
        collection: collection,
        documentID: id
      )
    else {
      throw PrismShortcutLoadError.missingConfiguration
    }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    if let bundleID = Bundle.main.bundleIdentifier {
      request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    }
    let (data, response) = try await metadataSession.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw PrismShortcutLoadError.badResponse
    }
    return data
  }
}
