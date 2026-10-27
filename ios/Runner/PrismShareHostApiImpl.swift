import UIKit

@MainActor
final class PrismShareHostApiImpl: @preconcurrency PrismShareHostApi {
  func canShareInstagramStory(target: InstagramStoryTarget) throws -> Bool {
    guard let url = URL(string: target.iosUrl) else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  func shareInstagramStory(target: InstagramStoryTarget, imagePath: String, completion: @escaping (Result<Bool, Error>) -> Void) {
    let temp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.resolvingSymlinksInPath().path
    let tempDirectory = temp.hasSuffix("/") ? temp : temp + "/"
    let file = URL(fileURLWithPath: imagePath).standardizedFileURL.resolvingSymlinksInPath()
    guard file.path.hasPrefix(tempDirectory),
          let url = URL(string: target.iosUrl),
          UIApplication.shared.canOpenURL(url),
          let data = try? Data(contentsOf: file)
    else {
      completion(.success(false))
      return
    }
    UIPasteboard.general.setItems(
      [[target.iosPasteboardKey: data]],
      options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
    )
    UIApplication.shared.open(url, options: [:]) { opened in completion(.success(opened)) }
  }
}
