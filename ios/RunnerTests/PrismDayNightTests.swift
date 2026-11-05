import Foundation
import XCTest

#if canImport(PrismShortcutsCore)
@testable import PrismShortcutsCore
#endif
#if canImport(Runner)
@testable import Runner
#endif

final class PrismDayNightTests: XCTestCase {
  private static let snapshot = #"{"dayStart":420,"nightStart":1140,"day":{"id":"prism_day","url":"https://example.com/day.jpg"},"night":{"id":"prism_abc","asset":"original:prism_abc"}}"#

  private func json(dayStart: String = "420", nightStart: String = "1140", day: String? = nil, night: String? = nil)
    -> String
  {
    let dayWall = day ?? #"{"id":"d","url":"https://example.com/d.jpg"}"#
    let nightWall = night ?? #"{"id":"n","url":"https://example.com/n.jpg"}"#
    return #"{"dayStart":\#(dayStart),"nightStart":\#(nightStart),"day":\#(dayWall),"night":\#(nightWall)}"#
  }

  private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
  }

  private func date(
    year: Int = 2026,
    month: Int = 11,
    day: Int = 4,
    hour: Int,
    minute: Int,
    zone: String = "UTC"
  ) -> Date {
    var components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    components.timeZone = TimeZone(identifier: zone)
    return calendar(zone).date(from: components)!
  }

  func testParsesValidSnapshotWithURLAndAssetWalls() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(Self.snapshot))
    XCTAssertEqual(parsed.dayStart, 420)
    XCTAssertEqual(parsed.nightStart, 1140)
    XCTAssertEqual(
      parsed.day, PrismShortcutFavourite(id: "prism_day", url: URL(string: "https://example.com/day.jpg")!)
    )
    XCTAssertEqual(parsed.night, PrismShortcutFavourite(id: "prism_abc", asset: "original:prism_abc"))
  }

  func testParseReturnsNilForInvalidSnapshots() {
    let invalid: [String?] = [
      nil,
      "",
      "{}",
      json(nightStart: "420"),
      json(dayStart: "1440"),
      json(dayStart: "-1"),
      json(dayStart: "420.5"),
      json(day: #"{"id":"d","url":"http://example.com/d.jpg"}"#),
    ]
    for value in invalid {
      XCTAssertNil(PrismDayNight.parse(value), "Expected nil for \(value ?? "nil")")
    }
  }

  func testSlotAtNoonIsDayAndAt2200IsNight() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(Self.snapshot))
    XCTAssertEqual(parsed.slot(at: date(hour: 12, minute: 0), calendar: calendar("UTC")), .day)
    XCTAssertEqual(parsed.slot(at: date(hour: 22, minute: 0), calendar: calendar("UTC")), .night)
  }

  func testDayWrapsPastMidnight() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(json(dayStart: "1320", nightStart: "360")))
    let utc = calendar("UTC")
    XCTAssertEqual(parsed.slot(at: date(hour: 23, minute: 30), calendar: utc), .day)
    XCTAssertEqual(parsed.slot(at: date(hour: 3, minute: 0), calendar: utc), .day)
    XCTAssertEqual(parsed.slot(at: date(hour: 12, minute: 0), calendar: utc), .night)
  }

  func testBoundariesStartDayAndNight() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(json(dayStart: "1320", nightStart: "360")))
    let utc = calendar("UTC")
    XCTAssertEqual(parsed.slot(at: date(hour: 22, minute: 0), calendar: utc), .day)
    XCTAssertEqual(parsed.slot(at: date(hour: 6, minute: 0), calendar: utc), .night)
  }

  func testSameDateIsDayInOneZoneAndNightInAnother() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(Self.snapshot))
    let noonUTC = date(hour: 12, minute: 0, zone: "UTC")
    XCTAssertEqual(parsed.slot(at: noonUTC, calendar: calendar("UTC")), .day)
    XCTAssertEqual(parsed.slot(at: noonUTC, calendar: calendar("America/Los_Angeles")), .night)
  }

  func testEveryMinuteMatchesTheHalfOpenIntervals() throws {
    for (dayStart, nightStart) in [(420, 1140), (1320, 360), (1, 0)] {
      let parsed = try XCTUnwrap(PrismDayNight.parse(json(dayStart: "\(dayStart)", nightStart: "\(nightStart)")))
      let utc = calendar("UTC")
      for minute in 0..<1440 {
        let date = date(hour: minute / 60, minute: minute % 60)
        let expected: PrismDayNightSlot = dayStart < nightStart
          ? (minute >= dayStart && minute < nightStart ? .day : .night)
          : (minute >= dayStart || minute < nightStart ? .day : .night)
        XCTAssertEqual(parsed.slot(at: date, calendar: utc), expected, "minute \(minute), \(dayStart)/\(nightStart)")
      }
    }
  }

  func testSpringGapAndRepeatedFallHourUseTheLocalWallClock() throws {
    let spring = try XCTUnwrap(PrismDayNight.parse(json(dayStart: "150", nightStart: "1320")))
    let springZone = calendar("America/Los_Angeles")
    let springStart = date(month: 3, day: 8, hour: 8, minute: 0).timeIntervalSince1970
    XCTAssertEqual(
      springZone.timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: springStart + 119 * 60)), -8 * 3600
    )
    XCTAssertEqual(
      springZone.timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: springStart + 120 * 60)), -7 * 3600
    )
    for minute in 0..<1380 {
      let wallMinute = minute < 120 ? minute : minute + 60
      let expected: PrismDayNightSlot = wallMinute >= 150 && wallMinute < 1320 ? .day : .night
      let instant = Date(timeIntervalSince1970: springStart + Double(minute * 60))
      XCTAssertEqual(spring.slot(at: instant, calendar: springZone), expected, "spring minute \(minute)")
    }

    let fall = try XCTUnwrap(PrismDayNight.parse(json(dayStart: "90", nightStart: "150")))
    let fallZone = calendar("America/Los_Angeles")
    let fallStart = date(month: 11, day: 1, hour: 7, minute: 0).timeIntervalSince1970
    XCTAssertEqual(fallZone.timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: fallStart + 119 * 60)), -7 * 3600)
    XCTAssertEqual(fallZone.timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: fallStart + 120 * 60)), -8 * 3600)
    for minute in 0..<1500 {
      let wallMinute = minute < 120 ? minute : minute - 60
      let expected: PrismDayNightSlot = wallMinute >= 90 && wallMinute < 150 ? .day : .night
      let instant = Date(timeIntervalSince1970: fallStart + Double(minute * 60))
      XCTAssertEqual(fall.slot(at: instant, calendar: fallZone), expected, "fall minute \(minute)")
    }
    for minute in [89, 90, 149, 150] {
      let wallMinute = minute < 120 ? minute : minute - 60
      let expected: PrismDayNightSlot = wallMinute >= 90 && wallMinute < 150 ? .day : .night
      XCTAssertEqual(
        fall.slot(at: Date(timeIntervalSince1970: fallStart + Double(minute * 60)), calendar: fallZone), expected
      )
    }
  }

  func testPublishedWallLoadRejectsSnapshotChangeDuringLoad() async throws {
    let suite = "PrismDayNightTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let snapshot = Self.snapshot
    defaults.set(snapshot, forKey: PrismDayNight.defaultsKey)
    defaults.set(3, forKey: PrismShortcutShuffle.sessionRevisionKey)
    let parsed = try XCTUnwrap(PrismDayNight.parse(snapshot))

    do {
      _ = try await PrismDayNight.loadPublishedWall(
        parsed.wall(for: .day), snapshot: snapshot, revision: 3, defaults: defaults
      ) { _ in
        await Task.yield()
        defaults.set("replacement", forKey: PrismDayNight.defaultsKey)
        return Data([1])
      }
      XCTFail("Expected a replaced snapshot to cancel the result")
    } catch is CancellationError {
      // The wall was loaded after the source snapshot changed.
    }
  }

  func testPublishedWallLoadRejectsSessionChangeDuringLoad() async throws {
    let suite = "PrismDayNightTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let snapshot = Self.snapshot
    defaults.set(snapshot, forKey: PrismDayNight.defaultsKey)
    defaults.set(3, forKey: PrismShortcutShuffle.sessionRevisionKey)
    let parsed = try XCTUnwrap(PrismDayNight.parse(snapshot))

    do {
      _ = try await PrismDayNight.loadPublishedWall(
        parsed.wall(for: .day), snapshot: snapshot, revision: 3, defaults: defaults
      ) { _ in
        await Task.yield()
        defaults.set(4, forKey: PrismShortcutShuffle.sessionRevisionKey)
        return Data([1])
      }
      XCTFail("Expected a changed session to cancel the result")
    } catch is CancellationError {
      // The user session changed while the wall was loading.
    }
  }

  func testPublishedUrlWallIsConvertedToLocalOnlyAssetKey() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(Self.snapshot))
    let day = parsed.wall(for: .day)
    XCTAssertNil(day.url)
    XCTAssertEqual(day.asset, "https://example.com/day.jpg")

    let night = parsed.wall(for: .night)
    XCTAssertNil(night.url)
    XCTAssertEqual(night.asset, "original:prism_abc")
  }

  func testWallForSlotReturnsMatchingWall() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(Self.snapshot))
    XCTAssertEqual(parsed.wall(for: .day).id, "prism_day")
    XCTAssertEqual(parsed.wall(for: .night).id, "prism_abc")
  }

}
