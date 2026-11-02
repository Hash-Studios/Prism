import Foundation

struct PrismShortcutFavourite: Equatable, Sendable {
  let id: String
  /// The public image. Nil for a protected wall, which has only the downloaded original under `asset`.
  let url: URL?
  let asset: String?

  init(id: String, url: URL) {
    self.id = id
    self.url = url
    asset = nil
  }

  init(id: String, asset: String) {
    self.id = id
    url = nil
    self.asset = asset
  }
}

enum PrismShortcutFavourites {
  static let defaultsKey = "flutter.shortcuts.favourites"
  static let nativeAssetPathsKey = "flutter.offline.native_asset_paths"
  static let maximumCount = 200
  /// Prism keys a protected wall's downloaded original as `original:<item key>` in the native asset paths.
  static let originalAssetPrefix = "original:"

  static func parse(_ json: String?) -> [PrismShortcutFavourite] {
    guard let json, let items = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any] else {
      return []
    }
    return parse(items, limit: maximumCount)
  }

  static func parse(_ items: [Any], limit: Int) -> [PrismShortcutFavourite] {
    items.prefix(limit).compactMap { item in
      guard let object = item as? [String: Any], let id = object["id"] as? String, !id.isEmpty else { return nil }
      if let link = object["url"] as? String, let url = httpsURL(link) {
        return PrismShortcutFavourite(id: id, url: url)
      }
      if let asset = object["asset"] as? String,
        asset.hasPrefix(originalAssetPrefix), asset.count > originalAssetPrefix.count
      {
        return PrismShortcutFavourite(id: id, asset: asset)
      }
      return nil
    }
  }

  static func httpsURL(_ link: String) -> URL? {
    guard let url = URL(string: link), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
      return nil
    }
    return url
  }
}
