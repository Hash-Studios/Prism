import UIKit

@MainActor
final class PrismAppIconHostApiImpl: @preconcurrency PrismAppIconHostApi {
  func setAppIcon(iconName: String?, completion: @escaping (Result<Bool, Error>) -> Void) {
    let application = UIApplication.shared
    guard application.supportsAlternateIcons else {
      completion(.success(false))
      return
    }
    Task {
      do {
        try await application.setAlternateIconName(iconName)
        completion(.success(true))
      } catch {
        completion(.success(false))
      }
    }
  }

  func currentAppIcon() throws -> String? {
    UIApplication.shared.alternateIconName
  }

  func supportsAlternateIcons() throws -> Bool {
    UIApplication.shared.supportsAlternateIcons
  }
}
