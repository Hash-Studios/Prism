import Foundation

struct PrismShortcutFavourite: Equatable, Sendable {
  let id: String
  let url: URL
}

enum PrismShortcutFavourites {
  static let defaultsKey = "flutter.shortcuts.favourites"
  static let nativeAssetPathsKey = "flutter.offline.native_asset_paths"
  static let maximumCount = 200

  static func parse(_ json: String?) -> [PrismShortcutFavourite] {
    guard let json, let items = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any] else {
      return []
    }
    return parse(items, limit: maximumCount)
  }

  static func parse(_ items: [Any], limit: Int) -> [PrismShortcutFavourite] {
    items.prefix(limit).compactMap { item in
      guard let object = item as? [String: Any],
        let id = object["id"] as? String, !id.isEmpty,
        let link = object["url"] as? String, let url = httpsURL(link)
      else {
        return nil
      }
      return PrismShortcutFavourite(id: id, url: url)
    }
  }

  static func httpsURL(_ link: String) -> URL? {
    guard let url = URL(string: link), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
      return nil
    }
    return url
  }
}
