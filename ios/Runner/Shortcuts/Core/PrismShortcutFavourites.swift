import Foundation

struct PrismShortcutFavourite: Equatable, Sendable {
  let id: String
  let url: URL
}

enum PrismShortcutFavourites {
  static let defaultsKey = "flutter.shortcuts.favourites"
  static let lastPickedDefaultsKey = "prism.shortcuts.lastPickedFavouriteId"
  static let maximumCount = 200

  static func parse(_ json: String?) -> [PrismShortcutFavourite] {
    guard let json, let items = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any] else {
      return []
    }
    return items.prefix(maximumCount).compactMap { item in
      guard let object = item as? [String: Any],
        let id = object["id"] as? String, !id.isEmpty,
        let link = object["url"] as? String, let url = httpsURL(link)
      else {
        return nil
      }
      return PrismShortcutFavourite(id: id, url: url)
    }
  }

  static func pick(
    from favourites: [PrismShortcutFavourite],
    excluding lastPickedID: String?,
    randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
  ) -> PrismShortcutFavourite? {
    let fresh = favourites.filter { $0.id != lastPickedID }
    let pool = fresh.isEmpty ? favourites : fresh
    guard !pool.isEmpty else { return nil }
    return pool[min(max(randomIndex(pool.count), 0), pool.count - 1)]
  }

  static func httpsURL(_ link: String) -> URL? {
    guard let url = URL(string: link), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
      return nil
    }
    return url
  }
}
