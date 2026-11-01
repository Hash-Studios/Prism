import AppIntents
import Foundation
import UIKit
import UniformTypeIdentifiers

@available(iOS 16.0, *)
enum PrismWallpaperSource: String, AppEnum {
  case wallOfTheDay
  case randomFavourite
  case rotationFolder
  case folder

  static var typeDisplayRepresentation: TypeDisplayRepresentation { "Wallpaper source" }

  static var caseDisplayRepresentations: [PrismWallpaperSource: DisplayRepresentation] {
    [
      .wallOfTheDay: "Wall of the Day",
      .randomFavourite: "Random favourite",
      .rotationFolder: "Rotation folder",
      .folder: "Folder"
    ]
  }
}

@available(iOS 16.0, *)
struct PrismFolderEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation { "Folder" }
  static var defaultQuery: PrismFolderEntityQuery { PrismFolderEntityQuery() }

  let id: String
  let name: String
  let itemCount: Int

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)", subtitle: "Wallpapers: \(itemCount)")
  }
}

/// Lists the folders in the snapshot Prism last wrote.
@available(iOS 16.0, *)
struct PrismFolderEntityQuery: EntityQuery {
  var suiteName: String?

  private var folders: [PrismFolderEntity] {
    let defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    return PrismShortcutFolders.parse(defaults.string(forKey: PrismShortcutFolders.defaultsKey)).map {
      PrismFolderEntity(id: $0.id, name: $0.name, itemCount: $0.itemCount)
    }
  }

  func entities(for identifiers: [String]) async throws -> [PrismFolderEntity] {
    let all = folders
    return identifiers.compactMap { id in all.first { $0.id == id } }
  }

  func suggestedEntities() async throws -> [PrismFolderEntity] { folders }
}

@available(iOS 16.0, *)
enum PrismShortcutError: Error, CustomLocalizedStringResourceConvertible {
  case noFavourites
  case wallOfTheDayUnavailable
  case favouriteUnavailable
  case noRotationFolder
  case folderEmpty
  case folderNotFound
  case folderWallUnavailable
  case unsupportedImage

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noFavourites:
      return "No favourites yet. Open Prism and tap the heart on a wallpaper."
    case .wallOfTheDayUnavailable:
      return "Open Prism and download today's Wall of the Day original, then run this Shortcut again."
    case .favouriteUnavailable:
      return "Could not load your favourite wallpaper. Check your connection."
    case .noRotationFolder:
      return "No rotation folder yet. Open Prism, open a folder, and tap Rotate this folder daily."
    case .folderEmpty:
      return "This folder is empty. Open Prism and save wallpapers to it."
    case .folderNotFound:
      return "Prism cannot find this folder. Open Prism to refresh your folders, then pick the folder again."
    case .folderWallUnavailable:
      return "Could not load a wallpaper from this folder. Check your connection."
    case .unsupportedImage:
      return "This wallpaper is in a format that Shortcuts cannot use."
    }
  }
}

@available(iOS 16.0, *)
struct GetPrismWallpaperIntent: AppIntent {
  static var title: LocalizedStringResource { "Get Prism Wallpaper" }

  static var description: IntentDescription {
    IntentDescription("Gets a Prism wallpaper. Pass it to the Set Wallpaper action.")
  }

  static var openAppWhenRun: Bool { false }

  @Parameter(title: "Source", default: .wallOfTheDay)
  var source: PrismWallpaperSource

  @Parameter(title: "Folder")
  var folder: PrismFolderEntity?

  static var parameterSummary: some ParameterSummary {
    When(\GetPrismWallpaperIntent.$source, .equalTo, PrismWallpaperSource.folder) {
      Summary("Get \(\.$source) wallpaper from \(\.$folder)")
    } otherwise: {
      Summary("Get \(\.$source) wallpaper")
    }
  }

  init() {}

  init(source: PrismWallpaperSource) {
    self.source = source
  }

  func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
    let data: Data
    switch source {
    case .wallOfTheDay:
      data = try await Self.wallOfTheDayImage()
    case .randomFavourite:
      data = try await Self.randomFavouriteImage()
    case .rotationFolder:
      let id = UserDefaults.standard.string(forKey: PrismShortcutFolders.rotationFolderKey)
      data = try await Self.folderImage(id: id, rotation: true)
    case .folder:
      guard let folder else { throw $folder.needsValueError() }
      data = try await Self.folderImage(id: folder.id, rotation: false)
    }
    return .result(value: try Self.file(from: data))
  }

  private static func wallOfTheDayImage() async throws -> Data {
    do {
      return try await PrismShortcutWallpaperLoader.wallOfTheDayImage()
    } catch let error as CancellationError {
      throw error
    } catch {
      throw PrismShortcutError.wallOfTheDayUnavailable
    }
  }

  private static func randomFavouriteImage() async throws -> Data {
    let defaults = UserDefaults.standard
    let snapshot = defaults.string(forKey: PrismShortcutFavourites.defaultsKey)
    let revision = PrismShortcutShuffle.sessionRevision(in: defaults)
    let favourites = PrismShortcutFavourites.parse(snapshot)
    guard !favourites.isEmpty else { throw PrismShortcutError.noFavourites }
    return try await shuffledImage(
      from: favourites,
      bagKey: PrismShortcutShuffle.favouritesKey,
      unavailable: .favouriteUnavailable,
      defaults: defaults,
      isCurrent: {
        PrismShortcutShuffle.snapshotMatchesSession(
          snapshot, for: PrismShortcutFavourites.defaultsKey, revision: revision, in: defaults
        )
      }
    )
  }

  static func folderImage(id: String?, rotation: Bool, defaults: UserDefaults = .standard) async throws -> Data {
    let snapshot = defaults.string(forKey: PrismShortcutFolders.defaultsKey)
    let revision = PrismShortcutShuffle.sessionRevision(in: defaults)
    let folders = PrismShortcutFolders.parse(snapshot)
    let folder: PrismShortcutFolder
    do {
      folder = try PrismShortcutFolders.resolve(id, in: folders, rotation: rotation)
    } catch PrismShortcutFolderError.noRotationFolder {
      throw PrismShortcutError.noRotationFolder
    } catch PrismShortcutFolderError.empty {
      throw PrismShortcutError.folderEmpty
    } catch {
      throw PrismShortcutError.folderNotFound
    }
    return try await shuffledImage(
      from: folder.items,
      bagKey: PrismShortcutFolders.bagKey(folderID: folder.id),
      unavailable: .folderWallUnavailable,
      defaults: defaults,
      isCurrent: {
        PrismShortcutShuffle.snapshotMatchesSession(
          snapshot, for: PrismShortcutFolders.defaultsKey, revision: revision, in: defaults
        )
      }
    )
  }

  /// The pass moves on only after the image loads, so a failed run does not use up a wall.
  private static func shuffledImage(
    from walls: [PrismShortcutFavourite],
    bagKey: String,
    unavailable: PrismShortcutError,
    defaults: UserDefaults = .standard,
    isCurrent: () -> Bool = { true }
  ) async throws -> Data {
    do {
      guard let picked = try await PrismShortcutShuffle.loadAndCommit(
        from: walls.map(\.id), key: bagKey, defaults: defaults,
        load: { id in
          guard let wall = walls.first(where: { $0.id == id }) else { throw unavailable }
          return try await PrismShortcutWallpaperLoader.imageData(from: wall.url)
        },
        validate: { _ = try Self.file(from: $0) },
        isCurrent: isCurrent
      ) else {
        throw unavailable
      }
      return picked.value
    } catch PrismShortcutError.unsupportedImage {
      throw PrismShortcutError.unsupportedImage
    } catch PrismShortcutShuffleError.sourceChanged {
      throw CancellationError()
    } catch let error as CancellationError {
      throw error
    } catch {
      throw unavailable
    }
  }

  private static func file(from data: Data) throws -> IntentFile {
    if let kind = PrismShortcutImageKind(data: data) {
      let type: UTType = kind == .png ? .png : .jpeg
      return IntentFile(data: data, filename: "prism-wallpaper.\(kind.filenameExtension)", type: type)
    }
    guard let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.95) else {
      throw PrismShortcutError.unsupportedImage
    }
    return IntentFile(data: jpeg, filename: "prism-wallpaper.jpg", type: .jpeg)
  }
}
