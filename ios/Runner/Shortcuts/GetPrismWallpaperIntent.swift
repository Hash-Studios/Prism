import AppIntents
import Foundation
import UIKit
import UniformTypeIdentifiers

@available(iOS 16.0, *)
enum PrismWallpaperSource: String, AppEnum {
  case wallOfTheDay
  case randomFavourite

  static var typeDisplayRepresentation: TypeDisplayRepresentation { "Wallpaper source" }

  static var caseDisplayRepresentations: [PrismWallpaperSource: DisplayRepresentation] {
    [
      .wallOfTheDay: "Wall of the Day",
      .randomFavourite: "Random favourite"
    ]
  }
}

@available(iOS 16.0, *)
enum PrismShortcutError: Error, CustomLocalizedStringResourceConvertible {
  case noFavourites
  case wallOfTheDayUnavailable
  case favouriteUnavailable
  case unsupportedImage

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noFavourites:
      return "No favourites yet. Open Prism and tap the heart on a wallpaper."
    case .wallOfTheDayUnavailable:
      return "Could not load the Wall of the Day. Check your connection."
    case .favouriteUnavailable:
      return "Could not load your favourite wallpaper. Check your connection."
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

  func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
    let data: Data
    switch source {
    case .wallOfTheDay:
      data = try await Self.wallOfTheDayImage()
    case .randomFavourite:
      data = try await Self.randomFavouriteImage()
    }
    return .result(value: try Self.file(from: data))
  }

  private static func wallOfTheDayImage() async throws -> Data {
    do {
      let url = try await PrismShortcutWallpaperLoader.wallOfTheDayImageURL()
      return try await PrismShortcutWallpaperLoader.imageData(from: url)
    } catch let error as CancellationError {
      throw error
    } catch {
      throw PrismShortcutError.wallOfTheDayUnavailable
    }
  }

  private static func randomFavouriteImage() async throws -> Data {
    let defaults = UserDefaults.standard
    let favourites = PrismShortcutFavourites.parse(defaults.string(forKey: PrismShortcutFavourites.defaultsKey))
    guard
      let favourite = PrismShortcutFavourites.pick(
        from: favourites,
        excluding: defaults.string(forKey: PrismShortcutFavourites.lastPickedDefaultsKey)
      )
    else {
      throw PrismShortcutError.noFavourites
    }
    let data: Data
    do {
      data = try await PrismShortcutWallpaperLoader.imageData(from: favourite.url)
    } catch let error as CancellationError {
      throw error
    } catch {
      throw PrismShortcutError.favouriteUnavailable
    }
    defaults.set(favourite.id, forKey: PrismShortcutFavourites.lastPickedDefaultsKey)
    return data
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
