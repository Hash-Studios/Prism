import Foundation

enum PrismShortcutLoadError: Error {
  case missingConfiguration
  case badResponse
  case missingField
}

enum PrismShortcutWallpaperLoader {
  static let maximumImageBytes = 40 * 1024 * 1024
  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60
    return URLSession(configuration: configuration)
  }()

  static func wallOfTheDayImageURL() async throws -> URL {
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

  static func imageData(from url: URL) async throws -> Data {
    let (file, response) = try await session.download(from: url)
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
    return try Data(contentsOf: file)
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
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw PrismShortcutLoadError.badResponse
    }
    return data
  }
}
