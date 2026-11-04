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

  private func date(hour: Int, minute: Int, zone: String = "UTC") -> Date {
    var components = DateComponents(year: 2026, month: 11, day: 4, hour: hour, minute: minute)
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

  func testWallForSlotReturnsMatchingWall() throws {
    let parsed = try XCTUnwrap(PrismDayNight.parse(Self.snapshot))
    XCTAssertEqual(parsed.wall(for: .day).id, "prism_day")
    XCTAssertEqual(parsed.wall(for: .night).id, "prism_abc")
  }
}
