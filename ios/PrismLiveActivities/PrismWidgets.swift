import ImageIO
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Wall of the Day data

/// The display thumbnail and its wall, kept in the App Group so the widget shows the last wall when offline.
enum PrismWotdCache {
  private static var directory: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PrismStreakStore.appGroup)?
      .appendingPathComponent("Library/Caches/WallOfTheDayWidget", isDirectory: true)
  }

  private static var cache: PrismWotdDiskCache? { directory.map { PrismWotdDiskCache(directory: $0) } }

  static func wall() -> PrismWotdWall? {
    cache?.load()?.wall
  }

  static func update(_ wall: PrismWotdWall, includeImage: Bool, image: () async throws -> Data) async throws {
    guard let cache else {
      if includeImage { throw CocoaError(.fileNoSuchFile) }
      return
    }
    try await cache.update(wall, includeImage: includeImage, image: image)
  }

  /// Decodes the cached thumbnail at no more than the widget's pixel size and crops it to fill. WidgetKit refuses
  /// images larger than the widget, and a full decode can pass the extension's memory limit.
  static func image(filling pixels: CGSize, expectedWall: PrismWotdWall) -> UIImage? {
    guard pixels.width > 0, pixels.height > 0, let record = cache?.load(), let directory,
      let imageFile = record.imageFile(in: directory, for: expectedWall),
      let source = CGImageSourceCreateWithURL(imageFile as CFURL, nil),
      let image = PrismWotdImage.decode(source, filling: pixels)
    else { return nil }
    return UIImage(cgImage: image)
  }
}

enum PrismWotdLoader {
  private static let maxImageBytes = 15 * 1024 * 1024
  private static let refreshCoordinator = PrismWotdRefreshCoordinator()

  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    configuration.timeoutIntervalForResource = 20
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: configuration)
  }()

  private struct Config {
    let projectID: String
    let apiKey: String
    let bundleID: String
  }

  /// The widget runs inside Prism.app/PlugIns, so it reads the app's Firebase config instead of shipping a copy.
  private static var config: Config? {
    let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    guard let app = Bundle(url: appURL),
      let url = app.url(forResource: "GoogleService-Info", withExtension: "plist"),
      let values = NSDictionary(contentsOf: url),
      let projectID = values["PROJECT_ID"] as? String, !projectID.isEmpty,
      let apiKey = values["API_KEY"] as? String, !apiKey.isEmpty,
      let bundleID = app.bundleIdentifier ?? values["BUNDLE_ID"] as? String
    else { return nil }
    return Config(projectID: projectID, apiKey: apiKey, bundleID: bundleID)
  }

  /// The wall to show, and the pick day when the fetch reached the server. A nil day means offline or failed.
  static func refresh(includeImage: Bool) async -> (wall: PrismWotdWall?, pickedDay: String?) {
    if !includeImage { return await load(includeImage: false) }
    return await refreshCoordinator.task { await load(includeImage: true) }.value
  }

  private static func load(includeImage: Bool) async -> (wall: PrismWotdWall?, pickedDay: String?) {
    let cached = PrismWotdCache.wall()
    guard let config else { return (cached, nil) }
    do {
      let pointer = try PrismShortcutWotdIdentity.pointer(
        try await document(config, collection: "wall_of_the_day", id: "current")
      )
      if let cached, cached.documentId == pointer.documentId, cached.pickedDay == pointer.day {
        return (cached, pointer.day)
      }
      let result = PrismWotdSelection.resolve(
        pointer: pointer, document: try await document(config, collection: "walls", id: pointer.documentId), cached: cached
      )
      guard let wall = result.wall, result.pickedDay != nil else { return result }
      try await PrismWotdCache.update(wall, includeImage: includeImage) { try await image(wall.imageURL) }
      return result
    } catch {
      return (cached, nil)
    }
  }

  private static func document(_ config: Config, collection: String, id: String) async throws -> Data {
    guard let url = PrismFirestoreREST.documentURL(
      projectID: config.projectID, apiKey: config.apiKey, collection: collection, documentID: id
    ) else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.setValue(config.bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    return try await fetch(request, limit: 256 * 1024)
  }

  private static func image(_ url: URL) async throws -> Data {
    try await fetch(URLRequest(url: url), limit: maxImageBytes)
  }

  private static func fetch(_ request: URLRequest, limit: Int) async throws -> Data {
    let (bytes, response) = try await session.bytes(for: request)
    defer { bytes.task.cancel() }
    guard (response as? HTTPURLResponse)?.statusCode == 200, limit > 0 else {
      throw URLError(.badServerResponse)
    }
    return try await PrismWotdBytes.read(bytes, limit: limit)
  }
}

// MARK: - Wall of the Day widget

struct PrismWotdEntry: TimelineEntry {
  let date: Date
  let wall: PrismWotdWall?
  let image: UIImage?
}

struct PrismWotdProvider: TimelineProvider {
  func placeholder(in context: Context) -> PrismWotdEntry {
    PrismWotdEntry(date: .now, wall: nil, image: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping @Sendable (PrismWotdEntry) -> Void) {
    let pixels = Self.pixels(context)
    if context.isPreview, PrismWotdCache.wall() == nil {
      completion(PrismWotdEntry(date: .now, wall: nil, image: nil))
      return
    }
    Task {
      let wall = await PrismWotdLoader.refresh(includeImage: pixels.width > 0).wall
      completion(PrismWotdEntry(
        date: .now, wall: wall, image: wall.flatMap { PrismWotdCache.image(filling: pixels, expectedWall: $0) }
      ))
    }
  }

  func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PrismWotdEntry>) -> Void) {
    let pixels = Self.pixels(context)
    Task {
      let now = Date.now
      let result = await PrismWotdLoader.refresh(includeImage: pixels.width > 0)
      let image = result.wall.flatMap { PrismWotdCache.image(filling: pixels, expectedWall: $0) }
      completion(Timeline(
        entries: [PrismWotdEntry(date: now, wall: result.wall, image: image)],
        policy: .after(PrismWotdSchedule.nextRefresh(after: now, pickedDay: result.pickedDay))
      ))
    }
  }

  /// Lock Screen widgets show no photo, so they skip the decode.
  private static func pixels(_ context: Context) -> CGSize {
    switch context.family {
    case .accessoryRectangular, .accessoryCircular, .accessoryInline: return .zero
    default:
      return PrismWotdImageBudget.boundedPixels(
        CGSize(width: context.displaySize.width * 3, height: context.displaySize.height * 3)
      )
    }
  }
}

struct PrismWotdWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: PrismWidgetKind.wallOfTheDay, provider: PrismWotdProvider()) { entry in
      PrismWotdView(entry: entry)
    }
    .configurationDisplayName(Text("Wall of the Day"))
    .description(Text("Today's wall from Prism, picked fresh every day."))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    .contentMarginsDisabled()
  }
}

struct PrismWotdView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetRenderingMode) private var renderingMode
  let entry: PrismWotdEntry

  private var widgetName: String {
    switch family {
    case .systemSmall: "wotd_small"
    case .systemMedium: "wotd_medium"
    case .systemLarge: "wotd_large"
    default: "wotd_lock"
    }
  }

  private var link: URL? {
    entry.wall.flatMap { PrismWidgetLink.wall($0, widget: widgetName) } ?? PrismWidgetLink.streak(widget: widgetName)
  }

  var body: some View {
    Group {
      if family == .accessoryRectangular {
        lockScreen.prismWidgetBackground(Color.clear)
      } else {
        homeScreen.prismWidgetBackground(Color.prismInk)
      }
    }
    .widgetURL(link)
  }

  private var lockScreen: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        PrismMark(size: 14)
        Text("New wall today").font(.headline).lineLimit(1)
      }
      Group {
        if let wall = entry.wall {
          line(wall) ?? Text("Today's pick is ready")
        } else {
          Text("Open Prism")
        }
      }
      .font(.subheadline)
      .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var homeScreen: some View {
    ZStack(alignment: .bottomLeading) {
      if let image = entry.image {
        photo(image)
      }
      let line = family == .systemSmall ? nil : entry.wall.flatMap(line)
      if line != nil, renderingMode == .fullColor {
        LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
      }
      VStack(alignment: .leading) {
        PrismMark(size: 22).widgetAccentable()
        Spacer(minLength: 0)
        if let line {
          line.font(.footnote.weight(.semibold)).foregroundStyle(.white).lineLimit(1).widgetAccentable()
        } else if entry.image == nil {
          Text("Wall of the Day").font(.footnote.weight(.semibold)).foregroundStyle(.white).widgetAccentable()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(14)
    }
  }

  /// A photo keeps its light and shade under the Home Screen tint, so desaturate it rather than flatten it to the
  /// accent colour. The text stays in the accent group, so it reads against the photo.
  @ViewBuilder
  private func photo(_ image: UIImage) -> some View {
    if #available(iOS 18.0, *) {
      Image(uiImage: image).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill()
    } else {
      Image(uiImage: image).resizable().scaledToFill()
    }
  }

  private func line(_ wall: PrismWotdWall) -> Text? {
    if let title = wall.title { return Text(verbatim: title) }
    if let creator = wall.creator { return Text("by \(creator)") }
    return nil
  }
}

// MARK: - Streak widget

struct PrismStreakEntry: TimelineEntry {
  let date: Date
  let display: PrismStreakDisplay?
}

struct PrismStreakProvider: TimelineProvider {
  private static let sample = PrismStreakDisplay(count: 12, keptToday: true)

  func placeholder(in context: Context) -> PrismStreakEntry {
    PrismStreakEntry(date: .now, display: Self.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping @Sendable (PrismStreakEntry) -> Void) {
    let now = Date.now
    let snapshot = PrismStreakStore.load()
    let display = snapshot == nil && context.isPreview ? Self.sample : PrismStreakRule.display(snapshot, at: now)
    completion(PrismStreakEntry(date: now, display: display))
  }

  /// One entry now and one at each of the next local midnights, so the ring empties and a lapsed streak resets
  /// without the app. The app reloads the timeline whenever the streak changes.
  func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PrismStreakEntry>) -> Void) {
    let now = Date.now
    guard let snapshot = PrismStreakStore.load() else {
      completion(Timeline(entries: [PrismStreakEntry(date: now, display: nil)], policy: .never))
      return
    }
    let dates = [now] + PrismStreakRule.midnights(after: now, utcOffsetMinutes: snapshot.utcOffsetMinutes, count: 4)
    completion(Timeline(
      entries: dates.map { PrismStreakEntry(date: $0, display: PrismStreakRule.display(snapshot, at: $0)) },
      policy: .atEnd
    ))
  }
}

struct PrismStreakWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: PrismWidgetKind.streak, provider: PrismStreakProvider()) { entry in
      PrismStreakView(entry: entry)
    }
    .configurationDisplayName(Text("Streak"))
    .description(Text("Your Prism streak at a glance."))
    .supportedFamilies([.accessoryCircular, .accessoryInline])
  }
}

struct PrismStreakView: View {
  @Environment(\.widgetFamily) private var family
  let entry: PrismStreakEntry

  var body: some View {
    Group {
      if family == .accessoryInline {
        inline
      } else {
        circular
      }
    }
    .prismWidgetBackground(Color.clear)
    .widgetURL(PrismWidgetLink.streak(widget: family == .accessoryInline ? "streak_inline" : "streak_circular"))
  }

  private var inline: some View {
    Group {
      if let display = entry.display {
        Text("\(display.count)-day streak")
      } else {
        Text("Open Prism")
      }
    }
  }

  @ViewBuilder
  private var circular: some View {
    if let display = entry.display {
      Gauge(value: display.keptToday ? 1 : 0) {
        Text("Streak")
      } currentValueLabel: {
        Text(display.count, format: .number)
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        display.keptToday
          ? Text("\(display.count)-day streak, kept today") : Text("\(display.count)-day streak, not kept yet today")
      )
    } else {
      ZStack {
        AccessoryWidgetBackground()
        PrismMark(size: 30)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Open Prism"))
    }
  }
}

extension View {
  @ViewBuilder
  func prismWidgetBackground<Background: View>(_ background: Background) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { background }
    } else {
      self.background(background)
    }
  }
}
