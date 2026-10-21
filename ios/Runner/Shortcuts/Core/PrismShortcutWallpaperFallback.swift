import Foundation

enum PrismShortcutWotdError: Error {
  case openPrism
}

struct PrismShortcutWotdIdentity: Equatable {
  let documentId: String
  let day: String

  static func utcDay(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
    return formatter.string(from: date)
  }

  static func day(_ raw: String) -> String? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: raw) { return utcDay(date) }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: raw).map(utcDay)
  }

  static func pointer(_ data: Data) throws -> Self {
    guard let documentId = PrismFirestoreREST.stringField("wallId", in: data),
      let rawDate = PrismFirestoreREST.timestampField("date", in: data),
      let day = day(rawDate)
    else { throw PrismShortcutWotdError.openPrism }
    return Self(documentId: documentId, day: day)
  }
}

enum PrismShortcutWallpaperFallback {
  static func resolve(
    current: Result<PrismShortcutWotdIdentity, Error>, retained: Data?, today: Date
  ) throws -> String {
    guard let retained,
      let fields = try? JSONSerialization.jsonObject(with: retained) as? [String: String],
      let documentId = fields["documentId"], !documentId.isEmpty,
      let rawDay = fields["featuredDayUtc"], let day = PrismShortcutWotdIdentity.day(rawDay),
      day == PrismShortcutWotdIdentity.utcDay(today),
      let assetKey = fields["assetKey"], assetKey == "wotd:\(documentId)"
    else { throw PrismShortcutWotdError.openPrism }
    switch current {
    case .success(let identity):
      guard identity == PrismShortcutWotdIdentity(documentId: documentId, day: day) else {
        throw PrismShortcutWotdError.openPrism
      }
    case .failure(let error):
      if error is CancellationError { throw error }
      // An invalid pointer is not a network outage and cannot justify fallback.
      if error is PrismShortcutWotdError { throw error }
    }
    return assetKey
  }
}
