import Foundation

enum PrismShortcutWallpaperFallback {
  static func resolve(fresh: Result<URL, Error>, retained: URL?) throws -> URL {
    switch fresh {
    case .success(let url):
      return url
    case .failure(let error):
      guard let retained else { throw error }
      return retained
    }
  }
}
