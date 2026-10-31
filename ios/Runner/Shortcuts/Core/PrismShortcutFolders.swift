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
    excluding excluded: Set<String> = [],
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
    remaining.removeAll(where: excluded.contains)
    guard !remaining.isEmpty else { return nil }
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

  /// Persists the candidate pass only after the selected item loads successfully.
  static func loadAndCommit<Value>(
    from ids: [String],
    key: String,
    defaults: UserDefaults,
    sessionRevision: Int = 0,
    randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) },
    load: (String) async throws -> Value,
    validate: (Value) throws -> Void = { _ in },
    isCurrent: () -> Bool = { true }
  ) async throws -> (id: String, value: Value)? {
    let picked: PrismShortcutShuffleReservations.Selection
    while true {
      switch PrismShortcutShuffleReservations.shared.reserve(
        from: ids, key: key, defaults: defaults, sessionRevision: sessionRevision, randomIndex: randomIndex
      ) {
      case .selected(let selection):
        picked = selection
        break
      case .empty:
        return nil
      case .wait(let version):
        try await PrismShortcutShuffleReservations.shared.waitForChange(
          key: key, defaults: defaults, sessionRevision: sessionRevision, afterVersion: version
        )
        try Task.checkCancellation()
        guard isCurrent() else { throw PrismShortcutShuffleError.sourceChanged }
        continue
      }
      break
    }
    do {
      let value = try await load(picked.reservation.id)
      try validate(value)
      guard isCurrent() else { throw PrismShortcutShuffleError.sourceChanged }
      let committed = PrismShortcutShuffleReservations.shared.commit(
        picked.reservation, from: ids, key: key, defaults: defaults,
        sessionRevision: sessionRevision, isCurrent: isCurrent
      )
      guard committed else { throw PrismShortcutShuffleError.sourceChanged }
      return (picked.reservation.id, value)
    } catch {
      PrismShortcutShuffleReservations.shared.release(
        picked.reservation, for: key, defaults: defaults, sessionRevision: sessionRevision
      )
      throw error
    }
  }

  fileprivate static func bags(in defaults: UserDefaults) -> [String: PrismShortcutShuffleBag] {
    guard let raw = defaults.string(forKey: defaultsKey),
      let all = try? JSONDecoder().decode([String: PrismShortcutShuffleBag].self, from: Data(raw.utf8))
    else {
      return [:]
    }
    return all
  }
}

final class PrismShortcutShuffleReservations: @unchecked Sendable {
  static let shared = PrismShortcutShuffleReservations()

  struct Reservation: Equatable, Sendable {
    let id: String
    let token: UUID
  }

  struct Selection {
    let reservation: Reservation
    let bag: PrismShortcutShuffleBag
  }

  enum ReserveResult {
    case selected(Selection)
    case wait(version: Int)
    case empty
  }

  private struct Waiter {
    let id: UUID
    let continuation: CheckedContinuation<Void, Never>
  }

  private struct Pool: Hashable {
    let defaults: ObjectIdentifier
    let key: String
    let sessionRevision: Int
  }

  private let lock = NSLock()
  private var reserved: [Pool: [String: UUID]] = [:]
  private var waiters: [Pool: [Waiter]] = [:]
  private var versions: [Pool: Int] = [:]

  func reserve(
    from ids: [String],
    key: String,
    defaults: UserDefaults,
    sessionRevision: Int,
    randomIndex: (Int) -> Int
  ) -> ReserveResult {
    lock.lock()
    defer { lock.unlock() }
    let pool = Pool(defaults: ObjectIdentifier(defaults), key: key, sessionRevision: sessionRevision)
    guard let picked = PrismShortcutShuffle.pick(
      from: ids,
      bag: PrismShortcutShuffle.bag(key, in: defaults),
      excluding: Set(reserved[pool]?.keys.map { $0 } ?? []),
      randomIndex: randomIndex
    ) else {
      return reserved[pool]?.isEmpty == false ? .wait(version: versions[pool] ?? 0) : .empty
    }
    let reservation = Reservation(id: picked.id, token: UUID())
    reserved[pool, default: [:]][picked.id] = reservation.token
    return .selected(Selection(reservation: reservation, bag: picked.bag))
  }

  func waitForChange(
    key: String,
    defaults: UserDefaults,
    sessionRevision: Int,
    afterVersion: Int
  ) async throws {
    let pool = Pool(defaults: ObjectIdentifier(defaults), key: key, sessionRevision: sessionRevision)
    let waiterID = UUID()
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        lock.lock()
        if Task.isCancelled || reserved[pool]?.isEmpty != false || (versions[pool] ?? 0) != afterVersion {
          lock.unlock()
          continuation.resume()
        } else {
          waiters[pool, default: []].append(Waiter(id: waiterID, continuation: continuation))
          lock.unlock()
        }
      }
    } onCancel: {
      self.cancelWaiter(waiterID, in: pool)
    }
    try Task.checkCancellation()
  }

  private func cancelWaiter(_ id: UUID, in pool: Pool) {
    lock.lock()
    defer { lock.unlock() }
    guard let index = waiters[pool]?.firstIndex(where: { $0.id == id }) else { return }
    let waiter = waiters[pool]!.remove(at: index)
    waiter.continuation.resume()
    if waiters[pool]?.isEmpty == true { waiters.removeValue(forKey: pool) }
  }

  func commit(
    _ reservation: Reservation,
    from ids: [String],
    key: String,
    defaults: UserDefaults,
    sessionRevision: Int,
    isCurrent: () -> Bool
  ) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard owns(reservation, key: key, defaults: defaults, sessionRevision: sessionRevision), isCurrent() else {
      return false
    }
    let pool = Set(ids)
    var shown: [String] = []
    var shownSet = Set<String>()
    for shownID in PrismShortcutShuffle.bag(key, in: defaults).shown where
      pool.contains(shownID) && shownSet.insert(shownID).inserted
    {
      shown.append(shownID)
    }
    if shownSet == pool {
      shown = []
      shownSet.removeAll()
    }
    if shownSet.insert(reservation.id).inserted { shown.append(reservation.id) }
    let committed = PrismShortcutShuffleBag(shown: shown, last: reservation.id)
    PrismShortcutShuffle.save(committed, for: key, in: defaults)
    guard isCurrent() else {
      var all = PrismShortcutShuffle.bags(in: defaults)
      if all[key] == committed {
        all.removeValue(forKey: key)
        if let data = try? JSONEncoder().encode(all) {
          defaults.set(String(decoding: data, as: UTF8.self), forKey: PrismShortcutShuffle.defaultsKey)
        }
      }
      return false
    }
    releaseUnlocked(reservation, for: key, defaults: defaults, sessionRevision: sessionRevision)
    return true
  }

  func release(
    _ reservation: Reservation,
    for key: String,
    defaults: UserDefaults,
    sessionRevision: Int
  ) {
    lock.lock()
    defer { lock.unlock() }
    releaseUnlocked(reservation, for: key, defaults: defaults, sessionRevision: sessionRevision)
  }

  private func releaseUnlocked(
    _ reservation: Reservation,
    for key: String,
    defaults: UserDefaults,
    sessionRevision: Int
  ) {
    let pool = Pool(defaults: ObjectIdentifier(defaults), key: key, sessionRevision: sessionRevision)
    guard reserved[pool]?[reservation.id] == reservation.token else { return }
    reserved[pool]?.removeValue(forKey: reservation.id)
    if reserved[pool]?.isEmpty == true { reserved.removeValue(forKey: pool) }
    versions[pool, default: 0] += 1
    let waiting = waiters.removeValue(forKey: pool) ?? []
    waiting.forEach { $0.continuation.resume() }
  }

  private func owns(
    _ reservation: Reservation,
    key: String,
    defaults: UserDefaults,
    sessionRevision: Int
  ) -> Bool {
    let pool = Pool(defaults: ObjectIdentifier(defaults), key: key, sessionRevision: sessionRevision)
    return reserved[pool]?[reservation.id] == reservation.token
  }
}
