import Foundation

enum PrismDayNightSlot: String, Equatable, Sendable { case day, night }

struct PrismDayNight: Equatable, Sendable {
  static let defaultsKey = "flutter.shortcuts.day_night"

  let dayStart: Int
  let nightStart: Int
  let day: PrismShortcutFavourite
  let night: PrismShortcutFavourite

  static func parse(_ json: String?) -> PrismDayNight? {
    guard let json,
      let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
      let dayStart = minutes(object["dayStart"]),
      let nightStart = minutes(object["nightStart"]),
      dayStart != nightStart,
      let day = wall(object["day"]),
      let night = wall(object["night"])
    else {
      return nil
    }
    return PrismDayNight(dayStart: dayStart, nightStart: nightStart, day: day, night: night)
  }

  func slot(at date: Date, calendar: Calendar = .current) -> PrismDayNightSlot {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
    let isDay = dayStart < nightStart
      ? minutes >= dayStart && minutes < nightStart
      : minutes >= dayStart || minutes < nightStart
    return isDay ? .day : .night
  }

  func wall(for slot: PrismDayNightSlot) -> PrismShortcutFavourite {
    let wall = slot == .day ? day : night
    if let url = wall.url {
      // Published URLs are keys for retained files, not permission to fetch from the network.
      return PrismShortcutFavourite(id: wall.id, asset: url.absoluteString)
    }
    return wall
  }

  static func loadPublishedWall(
    _ wall: PrismShortcutFavourite,
    snapshot: String?,
    revision: Int,
    defaults: UserDefaults,
    load: (PrismShortcutFavourite) async throws -> Data
  ) async throws -> Data {
    let data = try await load(wall)
    guard PrismShortcutShuffle.snapshotMatchesSession(
      snapshot, for: defaultsKey, revision: revision, in: defaults
    ) else {
      throw CancellationError()
    }
    return data
  }

  private static func minutes(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber else { return nil }
    #if canImport(Darwin)
    guard CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() else { return nil }
    #endif
    let time = number.intValue
    guard number.doubleValue == Double(time), (0..<1440).contains(time) else { return nil }
    return time
  }

  private static func wall(_ value: Any?) -> PrismShortcutFavourite? {
    guard let value else { return nil }
    return PrismShortcutFavourites.parse([value], limit: 1).first
  }
}
