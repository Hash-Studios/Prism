import WidgetKit

final class PrismWidgetHostApiImpl: PrismWidgetHostApi {
  func setStreakSnapshot(snapshot: StreakWidgetSnapshot?) throws {
    PrismStreakStore.save(snapshot.map {
      PrismStreakSnapshot(
        count: Int($0.count),
        lastKeptDay: $0.lastKeptDay,
        utcOffsetMinutes: Int($0.utcOffsetMinutes),
        freezes: Int($0.freezes)
      )
    })
    WidgetCenter.shared.reloadTimelines(ofKind: PrismWidgetKind.streak)
  }

  func reloadWallOfTheDay() throws {
    WidgetCenter.shared.reloadTimelines(ofKind: PrismWidgetKind.wallOfTheDay)
  }
}
