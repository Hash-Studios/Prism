import Foundation

struct PrismShortcutFolder: Equatable, Sendable {
  let id: String
  let name: String
  let itemCount: Int
  let items: [PrismShortcutFavourite]
}

enum PrismShortcutFolderError: Error, Equatable {
  case noRotationFolder
  case notFound
  case empty
}

enum PrismShortcutFolders {
  static let defaultsKey = "flutter.shortcuts.folders"
  static let rotationFolderKey = "flutter.shortcuts.rotation_folder"
  static let maximumFolders = 50
  static let maximumItems = 200

  /// The snapshot Prism writes: `{"folders": [{"id", "name", "itemCount", "items": [{"id", "url"}]}]}`.
  static func parse(_ json: String?) -> [PrismShortcutFolder] {
    guard let json,
      let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
      let folders = root["folders"] as? [Any]
    else {
      return []
    }
    var seen = Set<String>()
    return folders.compactMap { value -> PrismShortcutFolder? in
      guard let object = value as? [String: Any],
        let id = object["id"] as? String, !id.isEmpty,
        let name = object["name"] as? String,
        seen.insert(id).inserted
      else {
        return nil
      }
      return PrismShortcutFolder(
        id: id,
        name: name,
        itemCount: max(0, (object["itemCount"] as? NSNumber)?.intValue ?? 0),
        items: PrismShortcutFavourites.parse(object["items"] as? [Any] ?? [], limit: maximumItems)
      )
    }
    .prefix(maximumFolders)
    .map { $0 }
  }

  /// The folder to shuffle. `id` is nil when the user has not picked one.
  static func resolve(_ id: String?, in folders: [PrismShortcutFolder], rotation: Bool) throws -> PrismShortcutFolder {
    guard let id, !id.isEmpty else {
      throw rotation ? PrismShortcutFolderError.noRotationFolder : PrismShortcutFolderError.notFound
    }
    guard let folder = folders.first(where: { $0.id == id }) else { throw PrismShortcutFolderError.notFound }
    guard !folder.items.isEmpty else { throw PrismShortcutFolderError.empty }
    return folder
  }

  static func bagKey(folderID: String) -> String { "folder:\(folderID)" }
}

/// The walls of one pool shown in the current pass. A wall shows again only after every other wall has shown.
struct PrismShortcutShuffleBag: Codable, Equatable, Sendable {
  var shown: [String] = []
  var last: String?
}

enum PrismShortcutShuffleError: Error {
  case sourceChanged
}

enum PrismShortcutShuffle {
  static let defaultsKey = "flutter.shortcuts.shuffle_bags"
  static let favouritesKey = "favourites"
  static let sessionRevisionKey = "flutter.shortcuts.session_revision"

  static func sessionRevision(in defaults: UserDefaults) -> Int {
    defaults.object(forKey: sessionRevisionKey) as? Int ?? 0
  }

  static func snapshotMatchesSession(
    _ snapshot: String?,
    for key: String,
    revision: Int,
    in defaults: UserDefaults
  ) -> Bool {
    defaults.string(forKey: key) == snapshot && sessionRevision(in: defaults) == revision
  }

  /// Picks a wall not yet shown in this pass. Walls added since the pass began join it, removed walls leave it.
  /// A new pass does not start with the wall that ended the last one.
  static func pick(
    from ids: [String],
    bag: PrismShortcutShuffleBag,
    randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
  ) -> (id: String, bag: PrismShortcutShuffleBag)? {
    guard !ids.isEmpty else { return nil }
    let pool = Set(ids)
    var shown: [String] = []
    var shownSet = Set<String>()
    for id in bag.shown where pool.contains(id) && shownSet.insert(id).inserted {
      shown.append(id)
    }
    var remaining = ids.filter { !shownSet.contains($0) }
    if remaining.isEmpty {
      shown = []
      let fresh = ids.filter { $0 != bag.last }
      remaining = fresh.isEmpty ? ids : fresh
    }
    let id = remaining[min(max(randomIndex(remaining.count), 0), remaining.count - 1)]
    shown.append(id)
    return (id, PrismShortcutShuffleBag(shown: shown, last: id))
  }

  static func bag(_ key: String, in defaults: UserDefaults) -> PrismShortcutShuffleBag {
    bags(in: defaults)[key] ?? PrismShortcutShuffleBag()
  }

  static func save(_ bag: PrismShortcutShuffleBag, for key: String, in defaults: UserDefaults) {
    var all = bags(in: defaults)
    all[key] = bag
    guard let data = try? JSONEncoder().encode(all) else { return }
    defaults.set(String(decoding: data, as: UTF8.self), forKey: defaultsKey)
  }

  /// Saves the pass only after the wall loads, passes [validate], and still belongs to the same snapshot and session.
  /// ponytail: two runs at the same moment can pick the same wall. A daily automation does not overlap; add an
  /// in-process lock around pick and save if that changes.
  static func loadAndCommit<Value>(
    from ids: [String],
    key: String,
    defaults: UserDefaults,
    randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) },
    load: (String) async throws -> Value,
    validate: (Value) throws -> Void = { _ in },
    isCurrent: () -> Bool = { true }
  ) async throws -> (id: String, value: Value)? {
    guard let picked = pick(from: ids, bag: bag(key, in: defaults), randomIndex: randomIndex) else { return nil }
    let value = try await load(picked.id)
    try validate(value)
    guard isCurrent() else { throw PrismShortcutShuffleError.sourceChanged }
    save(picked.bag, for: key, in: defaults)
    return (picked.id, value)
  }

  private static func bags(in defaults: UserDefaults) -> [String: PrismShortcutShuffleBag] {
    guard let raw = defaults.string(forKey: defaultsKey),
      let all = try? JSONDecoder().decode([String: PrismShortcutShuffleBag].self, from: Data(raw.utf8))
    else {
      return [:]
    }
    return all
  }
}
