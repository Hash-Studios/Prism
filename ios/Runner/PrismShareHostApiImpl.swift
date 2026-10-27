import UIKit

@MainActor
final class PrismShareHostApiImpl: @preconcurrency PrismShareHostApi {
  func canShareInstagramStory(target: InstagramStoryTarget) throws -> Bool {
    guard let url = URL(string: target.iosUrl) else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  func shareInstagramStory(target: InstagramStoryTarget, imagePath: String, completion: @escaping (Result<Bool, Error>) -> Void) {
    let file = URL(fileURLWithPath: imagePath).standardizedFileURL.resolvingSymlinksInPath()
    // path_provider's getTemporaryDirectory uses Library/Caches on iOS.
    let directories = [URL(fileURLWithPath: NSTemporaryDirectory())]
      + FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    guard directories.contains(where: { directory in
            let path = directory.standardizedFileURL.resolvingSymlinksInPath().path
            return file.path.hasPrefix(path.hasSuffix("/") ? path : path + "/")
          }),
          (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
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
