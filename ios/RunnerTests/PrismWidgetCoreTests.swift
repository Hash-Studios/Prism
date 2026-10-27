import Foundation
import Testing

#if canImport(PrismShortcutsCore)
@testable import PrismShortcutsCore
#endif
#if canImport(Runner)
@testable import Runner
#endif

struct PrismWidgetCoreTests {
  private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
  }

  private func snapshot(count: Int = 12, day: String = "2026-10-27", offset: Int = 330, freezes: Int = 0)
    -> PrismStreakSnapshot
  {
    PrismStreakSnapshot(count: count, lastKeptDay: day, utcOffsetMinutes: offset, freezes: freezes)
  }

  // MARK: Timeline schedule

  @Test func refreshesAfterTomorrowsRotationOnceTodaysPickIsIn() {
    let now = date("2026-10-27T09:00:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: "2026-10-27") == date("2026-10-28T03:40:00Z"))
  }

  @Test func beforeTheRotationYesterdaysPickIsCurrent() {
    let now = date("2026-10-27T02:00:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: "2026-10-26") == date("2026-10-27T03:40:00Z"))
  }

  @Test func retriesSoonWhenTheServerHasNotRotatedYet() {
    let now = date("2026-10-27T03:35:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: "2026-10-26") == date("2026-10-27T04:05:00Z"))
  }

  @Test func retriesSoonWhenOffline() {
    let now = date("2026-10-27T12:00:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: nil) == date("2026-10-27T12:30:00Z"))
  }

  @Test func retryNeverPassesTheNextRotation() {
    let now = date("2026-10-28T03:25:00Z")
    #expect(PrismWotdSchedule.nextRefresh(after: now, pickedDay: nil) == date("2026-10-28T03:40:00Z"))
  }

  // MARK: Kept today

  @Test func keptTodayUntilLocalMidnight() {
    // 23:59 in India (UTC+5:30).
    let display = PrismStreakRule.display(snapshot(), at: date("2026-10-27T18:29:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: true))
  }

  @Test func afterLocalMidnightTheStreakLivesButTodayIsOpen() {
    // 00:01 on 28 October in India.
    let display = PrismStreakRule.display(snapshot(), at: date("2026-10-27T18:31:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: false))
  }

  @Test func theSameInstantIsStillTheKeptDayWestOfUTC() {
    // 11:31 on 27 October in California (UTC-7).
    let display = PrismStreakRule.display(snapshot(offset: -420), at: date("2026-10-27T18:31:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: true))
  }

  @Test func aMissedDayEndsTheStreakWithoutAFreeze() {
    let display = PrismStreakRule.display(snapshot(), at: date("2026-10-29T06:00:00Z"))
    #expect(display == PrismStreakDisplay(count: 0, keptToday: false))
  }

  @Test func aFreezeCoversAMissedDay() {
    let display = PrismStreakRule.display(snapshot(freezes: 1), at: date("2026-10-29T06:00:00Z"))
    #expect(display == PrismStreakDisplay(count: 12, keptToday: false))
  }

  @Test func signedOutHasNoStreak() {
    #expect(PrismStreakRule.display(nil, at: date("2026-10-27T06:00:00Z")) == nil)
  }

  @Test func anUnreadableDayShowsNoStreak() {
    let display = PrismStreakRule.display(snapshot(day: "2026-13-01"), at: date("2026-10-27T06:00:00Z"))
    #expect(display == PrismStreakDisplay(count: 0, keptToday: false))
  }

  @Test func timelineTurnsOverAtLocalMidnights() {
    let midnights = PrismStreakRule.midnights(after: date("2026-10-27T18:00:00Z"), utcOffsetMinutes: 330, count: 2)
    #expect(midnights == [date("2026-10-27T18:30:00Z"), date("2026-10-28T18:30:00Z")])
  }

  @Test func snapshotRoundTripsAndClears() throws {
    let suite = "PrismWidgetCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    PrismStreakStore.save(snapshot(), to: defaults)
    #expect(PrismStreakStore.load(from: defaults) == snapshot())
    PrismStreakStore.save(nil, to: defaults)
    #expect(PrismStreakStore.load(from: defaults) == nil)
  }

  // MARK: Wall of the Day REST parsing

  private let pointer = Data(
    #"{"fields":{"wallId":{"stringValue":"doc-1"},"date":{"timestampValue":"2026-10-27T03:30:12.5Z"}}}"#.utf8
  )

  @Test func parsesTheWallWithItsDisplayImage() throws {
    let wall = Data(#"""
      {"fields":{"id":{"stringValue":"share-1"},"title":{"stringValue":" Dusk "},"by":{"stringValue":"Akshay"},
      "wallpaper_thumb":{"stringValue":"https://cdn.example.com/t/1.jpg"},
      "wallpaper_url":{"stringValue":"https://cdn.example.com/o/1.png"}}}
      """#.utf8)
    let parsed = PrismWotdParser.wall(pointer: try PrismShortcutWotdIdentity.pointer(pointer), document: wall)
    #expect(parsed == PrismWotdWall(
      documentId: "doc-1",
      shareId: "share-1",
      imageURL: URL(string: "https://cdn.example.com/t/1.jpg")!,
      title: "Dusk",
      creator: "Akshay",
      pickedDay: "2026-10-27"
    ))
  }

  @Test func missingDisplayImageNeverFallsBackToTheOriginal() throws {
    let wall = Data(#"{"fields":{"wallpaper_url":{"stringValue":"https://cdn.example.com/o/1.png"}}}"#.utf8)
    #expect(PrismWotdParser.wall(pointer: try PrismShortcutWotdIdentity.pointer(pointer), document: wall) == nil)
  }

  @Test func blankOrInsecureImageIsMissing() throws {
    let identity = try PrismShortcutWotdIdentity.pointer(pointer)
    let blank = Data(#"{"fields":{"wallpaper_thumb":{"stringValue":"  "}}}"#.utf8)
    let insecure = Data(#"{"fields":{"wallpaper_thumb":{"stringValue":"http://cdn.example.com/t.jpg"}}}"#.utf8)
    #expect(PrismWotdParser.wall(pointer: identity, document: blank) == nil)
    #expect(PrismWotdParser.wall(pointer: identity, document: insecure) == nil)
  }

  @Test func shareIdFallsBackToTheDocumentId() throws {
    let wall = Data(#"{"fields":{"wallpaper_thumb":{"stringValue":"https://cdn.example.com/t.jpg"}}}"#.utf8)
    let parsed = PrismWotdParser.wall(pointer: try PrismShortcutWotdIdentity.pointer(pointer), document: wall)
    #expect(parsed?.shareId == "doc-1")
    #expect(parsed?.title == nil)
  }

  @Test func wallLinkIsTheShareLinkWithTheWidgetKind() {
    let wall = PrismWotdWall(
      documentId: "doc-1", shareId: "share 1", imageURL: URL(string: "https://cdn.example.com/t.jpg?w=1&h=2")!,
      title: nil, creator: nil, pickedDay: "2026-10-27"
    )
    #expect(PrismWidgetLink.wall(wall, widget: "wotd_small")?.absoluteString
      == "prism://share?id=share%201&source=prism&thumb=https%3A%2F%2Fcdn.example.com%2Ft.jpg%3Fw%3D1%26h%3D2&widget=wotd_small")
    #expect(PrismWidgetLink.streak(widget: "streak_inline")?.absoluteString == "prism://streak?widget=streak_inline")
  }
}
