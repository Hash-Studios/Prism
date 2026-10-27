import Foundation

enum PrismWidgetKind {
  static let wallOfTheDay = "PrismWallOfTheDay"
  static let streak = "PrismStreak"
}

/// What the app writes for the streak widgets. The app owns the streak; the widget only reads this copy.
struct PrismStreakSnapshot: Codable, Equatable, Sendable {
  let count: Int
  /// The last kept day as yyyy-MM-dd in the streak's time zone.
  let lastKeptDay: String
  let utcOffsetMinutes: Int
  let freezes: Int
}

struct PrismStreakDisplay: Equatable, Sendable {
  let count: Int
  let keptToday: Bool
}

enum PrismStreakStore {
  static let appGroup = "group.com.hash.prism"
  static let key = "widget.streak"

  static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> PrismStreakSnapshot? {
    guard let data = defaults?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(PrismStreakSnapshot.self, from: data)
  }

  static func save(_ snapshot: PrismStreakSnapshot?, to defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) {
    guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
      defaults?.removeObject(forKey: key)
      return
    }
    defaults?.set(data, forKey: key)
  }
}

enum PrismStreakRule {
  /// Mirrors isStreakAlive in lib/core/coins/coin_policy.dart: the streak lives while the gap since the last kept
  /// day is at most one day plus the held freezes. Nil means signed out.
  static func display(_ snapshot: PrismStreakSnapshot?, at now: Date) -> PrismStreakDisplay? {
    guard let snapshot else { return nil }
    let today = dayKey(now, utcOffsetMinutes: snapshot.utcOffsetMinutes)
    guard snapshot.count > 0, let gap = dayGap(from: snapshot.lastKeptDay, to: today),
      gap <= 1 + max(0, snapshot.freezes)
    else { return PrismStreakDisplay(count: 0, keptToday: false) }
    return PrismStreakDisplay(count: snapshot.count, keptToday: gap <= 0)
  }

  static func dayKey(_ date: Date, utcOffsetMinutes: Int) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: utcOffsetMinutes * 60) ?? utc
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  static func dayGap(from start: String, to end: String) -> Int? {
    guard let first = utcMidnight(start), let last = utcMidnight(end) else { return nil }
    return Int((last.timeIntervalSince(first) / 86_400).rounded())
  }

  /// The next local midnights in the streak's time zone, where the ring can change without the app.
  static func midnights(after now: Date, utcOffsetMinutes: Int, count: Int) -> [Date] {
    let offset = Double(utcOffsetMinutes * 60)
    let nextLocal = (floor((now.timeIntervalSince1970 + offset) / 86_400) + 1) * 86_400
    return (0..<count).map { Date(timeIntervalSince1970: nextLocal + Double($0) * 86_400 - offset) }
  }

  private static let utc = TimeZone(secondsFromGMT: 0)!

  private static func utcMidnight(_ key: String) -> Date? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard key.count == 10, parts.count == 3 else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
      dayKey(date, utcOffsetMinutes: 0) == key
    else { return nil }
    return date
  }
}

struct PrismWotdWall: Codable, Equatable, Sendable {
  let documentId: String
  /// Share links resolve walls by the `id` field, which is not the document id.
  let shareId: String
  let imageURL: URL
  let title: String?
  let creator: String?
  /// UTC yyyy-MM-dd of the pick, from wall_of_the_day/current.
  let pickedDay: String
}

enum PrismWotdParser {
  /// Nil when the wall has no display image. The widget never falls back to the original: it is too large.
  static func wall(pointer: PrismShortcutWotdIdentity, document: Data) -> PrismWotdWall? {
    guard let thumb = field("wallpaper_thumb", document), let url = URL(string: thumb), url.scheme == "https",
      url.host?.isEmpty == false
    else { return nil }
    return PrismWotdWall(
      documentId: pointer.documentId,
      shareId: field("id", document) ?? pointer.documentId,
      imageURL: url,
      title: field("title", document),
      creator: field("by", document),
      pickedDay: pointer.day
    )
  }

  private static func field(_ name: String, _ document: Data) -> String? {
    let value = PrismFirestoreREST.stringField(name, in: document)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return value?.isEmpty == false ? value : nil
  }
}

enum PrismWotdSchedule {
  /// functions/src/wallOfTheDay.ts picks a new wall every day at 03:30 UTC.
  static let rotationSecondOfDay: TimeInterval = 3 * 3_600 + 30 * 60
  /// Time for the pick and its retries to land before the widget asks.
  static let settle: TimeInterval = 10 * 60
  static let retry: TimeInterval = 30 * 60

  static func lastRotation(atOrBefore now: Date) -> Date {
    let today = floor(now.timeIntervalSince1970 / 86_400) * 86_400 + rotationSecondOfDay
    return Date(timeIntervalSince1970: today <= now.timeIntervalSince1970 ? today : today - 86_400)
  }

  /// After the next rotation. Sooner when the fetch failed or the server has not rotated yet, but never later.
  static func nextRefresh(after now: Date, pickedDay: String?) -> Date {
    let last = lastRotation(atOrBefore: now)
    let next = last.addingTimeInterval(86_400 + settle)
    guard pickedDay == PrismShortcutWotdIdentity.utcDay(last) else { return min(now.addingTimeInterval(retry), next) }
    return next
  }
}

enum PrismWidgetLink {
  private static let unreserved = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~"
  )

  /// The share link the app already parses, plus the widget kind for analytics.
  static func wall(_ wall: PrismWotdWall, widget: String) -> URL? {
    url("share", [("id", wall.shareId), ("source", "prism"), ("thumb", wall.imageURL.absoluteString), ("widget", widget)])
  }

  static func streak(widget: String) -> URL? {
    url("streak", [("widget", widget)])
  }

  private static func url(_ host: String, _ query: [(String, String)]) -> URL? {
    let pairs = query.compactMap { name, value in
      value.addingPercentEncoding(withAllowedCharacters: unreserved).map { "\(name)=\($0)" }
    }
    return URL(string: "prism://\(host)?\(pairs.joined(separator: "&"))")
  }
}
