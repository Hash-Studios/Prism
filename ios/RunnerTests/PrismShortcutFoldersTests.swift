import Foundation
import Testing

#if canImport(PrismShortcutsCore)
@testable import PrismShortcutsCore
#endif
#if canImport(Runner)
@testable import Runner
#endif

struct PrismShortcutFoldersTests {
  private static let snapshot = #"{"ownerId":"u1","folders":[{"id":"f1","name":"Calm","itemCount":2,"updatedAt":1,"items":[{"id":"prism_a","url":"https://example.com/a.jpg"}]},{"id":"f2","name":"Bold","itemCount":5,"updatedAt":2,"items":[]}]}"#

  private func folder(_ id: String, items: [String] = ["w1"]) -> PrismShortcutFolder {
    PrismShortcutFolder(
      id: id,
      name: id.uppercased(),
      itemCount: items.count,
      items: items.map { PrismShortcutFavourite(id: $0, url: URL(string: "https://example.com/\($0).jpg")!) }
    )
  }

  @Test func parseKeepsFolderOrderAndValues() {
    let folders = PrismShortcutFolders.parse(Self.snapshot)
    #expect(folders.map(\.id) == ["f1", "f2"])
    #expect(folders.first?.name == "Calm")
    #expect(folders.first?.itemCount == 2)
    #expect(folders.first?.items == [
      PrismShortcutFavourite(id: "prism_a", url: URL(string: "https://example.com/a.jpg")!)
    ])
  }

  @Test(arguments: [nil, "", "not json", "[]", "{}", #"{"folders":"x"}"#])
  func parseReturnsEmptyForMissingOrInvalidSnapshot(_ json: String?) {
    #expect(PrismShortcutFolders.parse(json).isEmpty)
  }

  @Test func parseSkipsInvalidFolders() {
    let json = """
      {"folders":[{"name":"No id","items":[]},{"id":"","name":"Empty id","items":[]},
      {"id":"bad","name":5,"items":[]},"text",
      {"id":"dup","name":"First","items":[]},{"id":"dup","name":"Second","items":[]},
      {"id":"ok","name":"Ok","itemCount":1,"items":[]}]}
      """
    let folders = PrismShortcutFolders.parse(json)
    #expect(folders.map(\.id) == ["dup", "ok"])
    #expect(folders.first?.name == "First")
  }

  @Test func parseDropsInvalidItemsAndKeepsFolder() {
    let json = """
      {"folders":[{"id":"f1","name":"Mixed","itemCount":6,"items":[
      {"id":"ok1","url":"https://example.com/1.jpg"},{"id":"http","url":"http://example.com/h.jpg"},
      {"url":"https://example.com/n.jpg"},{"id":"","url":"https://example.com/e.jpg"},
      {"id":"plain","url":"not a url"},{"id":"ok2","url":"https://example.com/2.jpg"}]}]}
      """
    let folders = PrismShortcutFolders.parse(json)
    #expect(folders.map(\.id) == ["f1"])
    #expect(folders.first?.itemCount == 6)
    #expect(folders.first?.items.map(\.id) == ["ok1", "ok2"])
  }

  @Test func parseClampsItemCountToZero() {
    let json = #"{"folders":[{"id":"neg","name":"Neg","itemCount":-4,"items":[]},{"id":"missing","name":"Missing","items":[]}]}"#
    let folders = PrismShortcutFolders.parse(json)
    #expect(folders.map(\.itemCount) == [0, 0])
  }

  @Test func parseCapsItemsAtTwoHundred() {
    let items = (0..<250).map { #"{"id":"w\#($0)","url":"https://example.com/\#($0).jpg"}"# }
    let json = #"{"folders":[{"id":"big","name":"Big","itemCount":250,"items":["#
      + items.joined(separator: ",") + "]}]}"
    let items200 = PrismShortcutFolders.parse(json).first?.items ?? []
    #expect(items200.count == 200)
    #expect(items200.first?.id == "w0")
    #expect(items200.last?.id == "w199")
  }

  @Test func parseCapsFoldersAtFifty() {
    let folders = (0..<60).map { #"{"id":"f\#($0)","name":"F","items":[]}"# }
    let json = #"{"folders":["# + folders.joined(separator: ",") + "]}"
    let parsed = PrismShortcutFolders.parse(json)
    #expect(parsed.count == PrismShortcutFolders.maximumFolders)
    #expect(parsed.count == 50)
    #expect(parsed.first?.id == "f0")
    #expect(parsed.last?.id == "f49")
  }

  @Test func resolveWithoutIDThrowsNoRotationFolderWhenRotating() {
    let folders = [folder("f1")]
    #expect(throws: PrismShortcutFolderError.noRotationFolder) {
      try PrismShortcutFolders.resolve(nil, in: folders, rotation: true)
    }
    #expect(throws: PrismShortcutFolderError.noRotationFolder) {
      try PrismShortcutFolders.resolve("", in: folders, rotation: true)
    }
  }

  @Test func resolveWithoutIDThrowsNotFoundWhenNotRotating() {
    #expect(throws: PrismShortcutFolderError.notFound) {
      try PrismShortcutFolders.resolve(nil, in: [folder("f1")], rotation: false)
    }
  }

  @Test func resolveUnknownIDThrowsNotFound() {
    let folders = [folder("f1")]
    #expect(throws: PrismShortcutFolderError.notFound) {
      try PrismShortcutFolders.resolve("gone", in: folders, rotation: true)
    }
    #expect(throws: PrismShortcutFolderError.notFound) {
      try PrismShortcutFolders.resolve("gone", in: folders, rotation: false)
    }
  }

  @Test func resolveFolderWithoutValidItemsThrowsEmpty() {
    #expect(throws: PrismShortcutFolderError.empty) {
      try PrismShortcutFolders.resolve("f1", in: [folder("f1", items: [])], rotation: false)
    }
  }

  @Test func resolveReturnsFolderWithItems() throws {
    let folders = [folder("f1"), folder("f2", items: ["a", "b"])]
    let resolved = try PrismShortcutFolders.resolve("f2", in: folders, rotation: true)
    #expect(resolved == folders[1])
  }

  @Test func shufflePickOfEmptyIDsIsNil() {
    #expect(PrismShortcutShuffle.pick(from: [], bag: PrismShortcutShuffleBag()) == nil)
  }

  @Test func shuffleDoesNotRepeatUntilExhausted() throws {
    let ids = ["a", "b", "c", "d"]
    for _ in 0..<50 {
      var bag = PrismShortcutShuffleBag()
      var first: [String] = []
      for _ in 0..<4 {
        let picked = try #require(PrismShortcutShuffle.pick(from: ids, bag: bag, randomIndex: { Int.random(in: 0..<$0) }))
        first.append(picked.id)
        bag = picked.bag
      }
      #expect(Set(first) == ["a", "b", "c", "d"])

      var second: [String] = []
      for _ in 0..<4 {
        let picked = try #require(PrismShortcutShuffle.pick(from: ids, bag: bag, randomIndex: { Int.random(in: 0..<$0) }))
        second.append(picked.id)
        bag = picked.bag
      }
      #expect(Set(second) == ["a", "b", "c", "d"])
    }
  }

  @Test func shuffleNewPassNeverStartsWithLastPick() throws {
    let bag = PrismShortcutShuffleBag(shown: ["a", "b", "c"], last: "c")
    let ids = ["a", "b", "c"]
    for index in 0..<2 {
      let picked = try #require(PrismShortcutShuffle.pick(from: ids, bag: bag, randomIndex: { _ in index }))
      #expect(picked.id != "c")
      #expect(picked.bag.shown == [picked.id])
    }
  }

  @Test func shuffleSingleItemRepeats() throws {
    let bag = PrismShortcutShuffleBag(shown: ["a"], last: "a")
    let picked = try #require(PrismShortcutShuffle.pick(from: ["a"], bag: bag))
    #expect(picked.id == "a")
  }

  @Test func shuffleTreatsDuplicateIDsAsOneWallInAPass() throws {
    let first = try #require(PrismShortcutShuffle.pick(from: ["a", "a", "b"], bag: PrismShortcutShuffleBag(), randomIndex: { _ in 0 }))
    #expect(first.id == "a")

    let second = try #require(PrismShortcutShuffle.pick(from: ["a", "a", "b"], bag: first.bag))
    #expect(second.id == "b")
  }

  @Test func shuffleAddedItemJoinsCurrentPass() throws {
    let bag = PrismShortcutShuffleBag(shown: ["a", "b"], last: "b")
    let ids = ["a", "b", "c", "d"]
    let first = try #require(PrismShortcutShuffle.pick(from: ids, bag: bag, randomIndex: { _ in 0 }))
    #expect(first.id == "c")
    #expect(first.bag.shown == ["a", "b", "c"])
    let second = try #require(PrismShortcutShuffle.pick(from: ids, bag: bag, randomIndex: { _ in 1 }))
    #expect(second.id == "d")
  }

  @Test func shuffleRemovedItemIsPrunedFromPass() throws {
    let bag = PrismShortcutShuffleBag(shown: ["a", "x"], last: "x")
    let picked = try #require(PrismShortcutShuffle.pick(from: ["a", "b"], bag: bag))
    #expect(picked.id == "b")
    #expect(picked.bag.shown == ["a", "b"])
  }

  @Test func shuffleAllShownItemsRemovedStartsNewPass() throws {
    let bag = PrismShortcutShuffleBag(shown: ["x", "y"], last: "y")
    let picked = try #require(PrismShortcutShuffle.pick(from: ["a", "b"], bag: bag, randomIndex: { _ in 0 }))
    #expect(picked.id == "a")
    #expect(picked.bag.shown == ["a"])
  }

  @Test func shuffleClampsOutOfRangeRandomIndex() throws {
    let ids = ["a", "b"]
    let high = try #require(PrismShortcutShuffle.pick(from: ids, bag: PrismShortcutShuffleBag(), randomIndex: { _ in 99 }))
    #expect(high.id == "b")
    let low = try #require(PrismShortcutShuffle.pick(from: ids, bag: PrismShortcutShuffleBag(), randomIndex: { _ in -3 }))
    #expect(low.id == "a")
  }

  @Test func shuffleBagsPersistPerKey() {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let f1 = PrismShortcutShuffleBag(shown: ["a"], last: "a")
    let f2 = PrismShortcutShuffleBag(shown: ["b", "c"], last: "c")
    let favourites = PrismShortcutShuffleBag(shown: ["z"], last: "z")

    PrismShortcutShuffle.save(f1, for: PrismShortcutFolders.bagKey(folderID: "f1"), in: defaults)
    PrismShortcutShuffle.save(f2, for: PrismShortcutFolders.bagKey(folderID: "f2"), in: defaults)
    PrismShortcutShuffle.save(favourites, for: PrismShortcutShuffle.favouritesKey, in: defaults)

    #expect(PrismShortcutShuffle.bag(PrismShortcutFolders.bagKey(folderID: "f1"), in: defaults) == f1)
    #expect(PrismShortcutShuffle.bag(PrismShortcutFolders.bagKey(folderID: "f2"), in: defaults) == f2)
    #expect(PrismShortcutShuffle.bag(PrismShortcutShuffle.favouritesKey, in: defaults) == favourites)
    #expect(PrismShortcutShuffle.bag("folder:unknown", in: defaults) == PrismShortcutShuffleBag())

    defaults.set("not json", forKey: PrismShortcutShuffle.defaultsKey)
    #expect(PrismShortcutShuffle.bag(PrismShortcutFolders.bagKey(folderID: "f1"), in: defaults) == PrismShortcutShuffleBag())

    defaults.removePersistentDomain(forName: suite)
  }

  @Test func shuffleOnlyCommitsAfterSuccessfulLoad() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let key = PrismShortcutShuffle.favouritesKey
    let original = PrismShortcutShuffleBag(shown: ["a"], last: "a")
    PrismShortcutShuffle.save(original, for: key, in: defaults)

    await #expect(throws: TestLoadError.failed) {
      try await PrismShortcutShuffle.loadAndCommit(
        from: ["a", "b"], key: key, defaults: defaults, randomIndex: { _ in 0 },
        load: { _ in throw TestLoadError.failed }
      )
    }
    #expect(PrismShortcutShuffle.bag(key, in: defaults) == original)

    await #expect(throws: TestValidationError.failed) {
      try await PrismShortcutShuffle.loadAndCommit(
        from: ["a", "b"], key: key, defaults: defaults, randomIndex: { _ in 0 },
        load: { "invalid image bytes for \($0)" },
        validate: { _ in throw TestValidationError.failed }
      )
    }
    #expect(PrismShortcutShuffle.bag(key, in: defaults) == original)

    let loaded = try #require(try await PrismShortcutShuffle.loadAndCommit(
      from: ["a", "b"], key: key, defaults: defaults, randomIndex: { _ in 0 },
      load: { "data for \($0)" }
    ))
    #expect(loaded.id == "b")
    #expect(loaded.value == "data for b")
    #expect(PrismShortcutShuffle.bag(key, in: defaults) == PrismShortcutShuffleBag(shown: ["a", "b"], last: "b"))

    defaults.removePersistentDomain(forName: suite)
  }

  @Test func shuffleRejectsSnapshotRestoredInANewSession() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let key = PrismShortcutShuffle.favouritesKey
    let revisionKey = PrismShortcutShuffle.sessionRevisionKey
    defaults.set("old snapshot", forKey: PrismShortcutFavourites.defaultsKey)
    defaults.set(1, forKey: revisionKey)

    await #expect(throws: PrismShortcutShuffleError.sourceChanged) {
      try await PrismShortcutShuffle.loadAndCommit(
        from: ["a", "b"], key: key, defaults: defaults, randomIndex: { _ in 0 },
        load: { id in
          defaults.set("cleared snapshot", forKey: PrismShortcutFavourites.defaultsKey)
          defaults.set("old snapshot", forKey: PrismShortcutFavourites.defaultsKey)
          defaults.set(2, forKey: revisionKey)
          return id
        },
        isCurrent: {
          PrismShortcutShuffle.snapshotMatchesSession(
            "old snapshot", for: PrismShortcutFavourites.defaultsKey, revision: 1, in: defaults
          )
        }
      )
    }
    #expect(PrismShortcutShuffle.bag(key, in: defaults) == PrismShortcutShuffleBag())

    defaults.set("old snapshot", forKey: PrismShortcutFavourites.defaultsKey)
    var checks = 0
    await #expect(throws: PrismShortcutShuffleError.sourceChanged) {
      try await PrismShortcutShuffle.loadAndCommit(
        from: ["a", "b"], key: key, defaults: defaults, randomIndex: { _ in 0 },
        load: { $0 },
        isCurrent: {
          checks += 1
          return checks == 1
        }
      )
    }
    #expect(PrismShortcutShuffle.bag(key, in: defaults) == PrismShortcutShuffleBag())

    defaults.removePersistentDomain(forName: suite)
  }

  @Test func overlappingLoadsReserveDifferentWallsAndMergeProgress() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let defaultsBox = TestDefaultsBox(defaults)
    let key = PrismShortcutShuffle.favouritesKey

    async let first = PrismShortcutShuffle.loadAndCommit(
      from: ["a", "b"], key: key, defaults: defaultsBox.defaults, randomIndex: { _ in 0 },
      load: { id in
        try await Task.sleep(for: .milliseconds(30))
        return id
      }
    )
    async let second = PrismShortcutShuffle.loadAndCommit(
      from: ["a", "b"], key: key, defaults: defaultsBox.defaults, randomIndex: { _ in 0 },
      load: { id in
        try await Task.sleep(for: .milliseconds(30))
        return id
      }
    )
    let results = try await [first, second]
    #expect(Set(results.compactMap { $0?.id }) == ["a", "b"])
    #expect(Set(PrismShortcutShuffle.bag(key, in: defaultsBox.defaults).shown) == ["a", "b"])

    defaults.removePersistentDomain(forName: suite)
  }

  @Test func overlappingLoadsAtPassBoundaryMergeOutOfOrderSuccesses() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let defaultsBox = TestDefaultsBox(defaults)
    let key = PrismShortcutShuffle.favouritesKey
    PrismShortcutShuffle.save(PrismShortcutShuffleBag(shown: ["a", "b", "c"], last: "c"), for: key, in: defaults)

    async let first = PrismShortcutShuffle.loadAndCommit(
      from: ["a", "b", "c"], key: key, defaults: defaultsBox.defaults, randomIndex: { _ in 0 },
      load: { id in
        try await Task.sleep(for: .milliseconds(id == "a" ? 30 : 1))
        return id
      }
    )
    async let second = PrismShortcutShuffle.loadAndCommit(
      from: ["a", "b", "c"], key: key, defaults: defaultsBox.defaults, randomIndex: { _ in 0 },
      load: { id in
        try await Task.sleep(for: .milliseconds(id == "a" ? 30 : 1))
        return id
      }
    )
    let results = try await [first, second]
    #expect(Set(results.compactMap { $0?.id }) == ["a", "b"])

    let bag = PrismShortcutShuffle.bag(key, in: defaultsBox.defaults)
    #expect(Set(bag.shown) == ["a", "b"])
    let finalWall = try #require(PrismShortcutShuffle.pick(from: ["a", "b", "c"], bag: bag))
    #expect(finalWall.id == "c")

    defaults.removePersistentDomain(forName: suite)
  }

  @Test func staleReservationReleaseCannotClearNewReservation() throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let key = PrismShortcutShuffle.favouritesKey
    let reservations = PrismShortcutShuffleReservations.shared
    let first = try #require(selected(reservations.reserve(
      from: ["a"], key: key, defaults: defaults, sessionRevision: 1, randomIndex: { _ in 0 }
    )))

    reservations.release(first.reservation, for: key, defaults: defaults, sessionRevision: 1)
    let second = try #require(selected(reservations.reserve(
      from: ["a"], key: key, defaults: defaults, sessionRevision: 1, randomIndex: { _ in 0 }
    )))
    #expect(second.reservation.id == first.reservation.id)
    #expect(second.reservation.token != first.reservation.token)

    reservations.release(first.reservation, for: key, defaults: defaults, sessionRevision: 1)
    #expect(isWaiting(reservations.reserve(
      from: ["a"], key: key, defaults: defaults, sessionRevision: 1, randomIndex: { _ in 0 }
    )))

    let newSession = try #require(selected(reservations.reserve(
      from: ["a"], key: key, defaults: defaults, sessionRevision: 2, randomIndex: { _ in 0 }
    )))
    #expect(newSession.reservation.id == second.reservation.id)
    reservations.release(second.reservation, for: key, defaults: defaults, sessionRevision: 1)
    reservations.release(newSession.reservation, for: key, defaults: defaults, sessionRevision: 2)
    defaults.removePersistentDomain(forName: suite)
  }

  private func selected(_ result: PrismShortcutShuffleReservations.ReserveResult)
    -> PrismShortcutShuffleReservations.Selection? {
    guard case .selected(let selection) = result else { return nil }
    return selection
  }

  private func isWaiting(_ result: PrismShortcutShuffleReservations.ReserveResult) -> Bool {
    if case .wait = result { return true }
    return false
  }

  @Test func reservationWaitDoesNotMissAnotherWallBecomingAvailable() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let reservations = PrismShortcutShuffleReservations.shared
    let key = PrismShortcutShuffle.favouritesKey
    let first = try #require(selected(reservations.reserve(
      from: ["a", "b"], key: key, defaults: defaults, sessionRevision: 1, randomIndex: { _ in 0 }
    )))
    let second = try #require(selected(reservations.reserve(
      from: ["a", "b"], key: key, defaults: defaults, sessionRevision: 1, randomIndex: { _ in 0 }
    )))
    #expect(first.reservation.id != second.reservation.id)
    let blocked = reservations.reserve(
      from: ["a", "b"], key: key, defaults: defaults, sessionRevision: 1, randomIndex: { _ in 0 }
    )
    guard case .wait(let version) = blocked else {
      Issue.record("Expected all walls in the pool to be reserved")
      return
    }

    reservations.release(first.reservation, for: key, defaults: defaults, sessionRevision: 1)
    try await reservations.waitForChange(
      key: key, defaults: defaults, sessionRevision: 1, afterVersion: version
    )
    let available = try #require(selected(reservations.reserve(
      from: ["a", "b"], key: key, defaults: defaults, sessionRevision: 1, randomIndex: { _ in 0 }
    )))
    #expect(available.reservation.id == first.reservation.id)

    reservations.release(second.reservation, for: key, defaults: defaults, sessionRevision: 1)
    reservations.release(available.reservation, for: key, defaults: defaults, sessionRevision: 1)
    defaults.removePersistentDomain(forName: suite)
  }

  @Test func newSessionCanLoadSameWallWhileOldLoadIsPending() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let defaultsBox = TestDefaultsBox(defaults)
    let key = PrismShortcutShuffle.favouritesKey
    let revisionKey = PrismShortcutShuffle.sessionRevisionKey
    let oldLoadGate = TestLoadGate()
    defaults.set("same favourites", forKey: PrismShortcutFavourites.defaultsKey)
    defaults.set(1, forKey: revisionKey)

    let oldSession = Task {
      try await PrismShortcutShuffle.loadAndCommit(
        from: ["a"], key: key, defaults: defaultsBox.defaults, sessionRevision: 1,
        load: { _ in
          await oldLoadGate.pause()
          return "old data"
        },
        isCurrent: {
          PrismShortcutShuffle.snapshotMatchesSession(
            "same favourites", for: PrismShortcutFavourites.defaultsKey, revision: 1, in: defaultsBox.defaults
          )
        }
      )
    }
    await oldLoadGate.waitUntilPaused()

    defaults.set(2, forKey: revisionKey)
    let newSession = try #require(try await PrismShortcutShuffle.loadAndCommit(
      from: ["a"], key: key, defaults: defaults, sessionRevision: 2,
      load: { _ in "new data" },
      isCurrent: {
        PrismShortcutShuffle.snapshotMatchesSession(
          "same favourites", for: PrismShortcutFavourites.defaultsKey, revision: 2, in: defaults
        )
      }
    ))
    #expect(newSession.id == "a")
    #expect(newSession.value == "new data")

    await oldLoadGate.resume()
    await #expect(throws: PrismShortcutShuffleError.sourceChanged) {
      try await oldSession.value
    }
    #expect(PrismShortcutShuffle.bag(key, in: defaults) == PrismShortcutShuffleBag(shown: ["a"], last: "a"))

    defaults.removePersistentDomain(forName: suite)
  }

  @Test func overlappingSingleWallLoadWaitsForInFlightResult() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let defaultsBox = TestDefaultsBox(defaults)
    let key = PrismShortcutShuffle.favouritesKey
    let firstLoadGate = TestLoadGate()

    let first = Task {
      try await PrismShortcutShuffle.loadAndCommit(
        from: ["only"], key: key, defaults: defaultsBox.defaults,
        load: { _ in
          await firstLoadGate.pause()
          return "first image"
        }
      )
    }
    await firstLoadGate.waitUntilPaused()

    let second = Task {
      try await PrismShortcutShuffle.loadAndCommit(
        from: ["only"], key: key, defaults: defaultsBox.defaults,
        load: { _ in "second image" }
      )
    }
    try await Task.sleep(for: .milliseconds(30))
    await firstLoadGate.resume()

    let firstResult = try #require(try await first.value)
    let secondResult = try #require(try await second.value)
    #expect(firstResult.id == "only")
    #expect(secondResult.id == "only")
    #expect(secondResult.value == "second image")

    defaults.removePersistentDomain(forName: suite)
  }

#if canImport(Runner)
  @available(iOS 16.0, *)
  @Test func folderQuerySuggestsSnapshotFolders() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(Self.snapshot, forKey: PrismShortcutFolders.defaultsKey)

    let query = PrismFolderEntityQuery(suiteName: suite)
    let suggested = try await query.suggestedEntities()
    #expect(suggested.map(\.id) == ["f1", "f2"])
    #expect(suggested.map(\.name) == ["Calm", "Bold"])
    #expect(suggested.map(\.itemCount) == [2, 5])

    let found = try await query.entities(for: ["f2", "missing", "f1"])
    #expect(found.map(\.id) == ["f2", "f1"])

    defaults.removePersistentDomain(forName: suite)
  }

  @available(iOS 16.0, *)
  @Test func folderQueryIsEmptyWithoutSnapshot() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!

    let suggested = try await PrismFolderEntityQuery(suiteName: suite).suggestedEntities()
    #expect(suggested.isEmpty)

    defaults.removePersistentDomain(forName: suite)
  }

  @available(iOS 16.0, *)
  @Test func folderImageWithoutRotationFolderThrowsNoRotationFolder() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!

    await #expect(throws: PrismShortcutError.noRotationFolder) {
      try await GetPrismWallpaperIntent.folderImage(id: nil, rotation: true, defaults: defaults)
    }

    defaults.removePersistentDomain(forName: suite)
  }

  @available(iOS 16.0, *)
  @Test func folderImageWithUnknownFolderThrowsNotFound() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(Self.snapshot, forKey: PrismShortcutFolders.defaultsKey)

    await #expect(throws: PrismShortcutError.folderNotFound) {
      try await GetPrismWallpaperIntent.folderImage(id: "gone", rotation: false, defaults: defaults)
    }

    defaults.removePersistentDomain(forName: suite)
  }

  @available(iOS 16.0, *)
  @Test func folderImageWithoutItemsThrowsFolderEmpty() async throws {
    let suite = "prism-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(Self.snapshot, forKey: PrismShortcutFolders.defaultsKey)

    await #expect(throws: PrismShortcutError.folderEmpty) {
      try await GetPrismWallpaperIntent.folderImage(id: "f2", rotation: false, defaults: defaults)
    }

    defaults.removePersistentDomain(forName: suite)
  }

  @available(iOS 16.0, *)
  @Test func folderErrorsHaveEnglishMessages() {
    #expect(String(localized: PrismShortcutError.noRotationFolder.localizedStringResource).contains("Rotate this folder daily"))
    #expect(String(localized: PrismShortcutError.folderEmpty.localizedStringResource).contains("empty"))
    #expect(String(localized: PrismShortcutError.folderNotFound.localizedStringResource).contains("cannot find"))
  }

  @available(iOS 16.0, *)
  @Test func legacyWallpaperSourceRawValuesStillDecode() {
    #expect(PrismWallpaperSource(rawValue: "wallOfTheDay") == .wallOfTheDay)
    #expect(PrismWallpaperSource(rawValue: "randomFavourite") == .randomFavourite)
    #expect(GetPrismWallpaperIntent().source == .wallOfTheDay)
  }
#endif
}

private enum TestLoadError: Error {
  case failed
}

private enum TestValidationError: Error {
  case failed
}

private final class TestDefaultsBox: @unchecked Sendable {
  let defaults: UserDefaults

  init(_ defaults: UserDefaults) {
    self.defaults = defaults
  }
}

private actor TestLoadGate {
  private var started = false
  private var released = false
  private var startedWaiter: CheckedContinuation<Void, Never>?
  private var releaseWaiter: CheckedContinuation<Void, Never>?

  func pause() async {
    started = true
    startedWaiter?.resume()
    startedWaiter = nil
    guard !released else { return }
    await withCheckedContinuation { releaseWaiter = $0 }
  }

  func waitUntilPaused() async {
    guard !started else { return }
    await withCheckedContinuation { startedWaiter = $0 }
  }

  func resume() {
    released = true
    releaseWaiter?.resume()
    releaseWaiter = nil
  }
}
