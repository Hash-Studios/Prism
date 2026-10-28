import Foundation
#if canImport(PrismNotificationCore)
import PrismNotificationCore
#endif
import UserNotifications

/// Attaches the push image. A gallery shows its lead wall as the collapsed thumbnail and the full row when expanded.
/// Any failure delivers the push as text.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
  private let lock = NSLock()
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var content: UNMutableNotificationContent?
  private var work: Task<Void, Never>?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
    lock.lock()
    self.contentHandler = contentHandler
    self.content = content
    lock.unlock()
    guard let image = PushImageRequest(userInfo: content.userInfo) else { return deliver(attachment: nil) }
    work = Task { [weak self] in
      let session = URLSession(configuration: .ephemeral)
      defer { session.invalidateAndCancel() }
      var attachment: UNNotificationAttachment?
      if let file = try? await PushImage.download(image.url, session: session) {
        let options = image.clip.map { [UNNotificationAttachmentOptionsThumbnailClippingRectKey: $0.dictionaryRepresentation] }
        attachment = try? UNNotificationAttachment(identifier: "image", url: file, options: options)
      }
      self?.deliver(attachment: attachment)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    work?.cancel()
    deliver(attachment: nil)
  }

  /// Calls the handler once. A late download after the time limit is dropped.
  private func deliver(attachment: UNNotificationAttachment?) {
    lock.lock()
    let handler = contentHandler
    contentHandler = nil
    lock.unlock()
    guard let handler, let content else { return }
    if let attachment { content.attachments = [attachment] }
    handler(content)
  }
}
