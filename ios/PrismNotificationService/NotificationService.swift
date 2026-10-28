import Foundation
#if canImport(UserNotifications)
import UserNotifications

final class NotificationDelivery: @unchecked Sendable {
  private let lock = NSLock()
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var content: UNMutableNotificationContent?

  init(content: UNMutableNotificationContent, contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.content = content
    self.contentHandler = contentHandler
  }

  var isFinished: Bool {
    lock.lock()
    defer { lock.unlock() }
    return contentHandler == nil
  }

  func finish(attachment: UNNotificationAttachment?) {
    lock.lock()
    let handler = contentHandler
    let content = self.content
    contentHandler = nil
    self.content = nil
    lock.unlock()
    guard let handler, let content else { return }
    if let attachment { content.attachments = [attachment] }
    handler(content)
  }
}

/// Attaches the push image. A gallery shows its lead wall as the collapsed thumbnail and the full row when expanded.
/// Any failure delivers the push as text.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
  private let lock = NSLock()
  private var delivery: NotificationDelivery?
  private var work: Task<Void, Never>?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
    let delivery = NotificationDelivery(content: content, contentHandler: contentHandler)
    lock.lock()
    self.delivery = delivery
    lock.unlock()
    guard let image = PushImageRequest(userInfo: content.userInfo) else { return delivery.finish(attachment: nil) }

    lock.lock()
    guard self.delivery === delivery, !delivery.isFinished else {
      lock.unlock()
      return
    }
    work = Task {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.timeoutIntervalForRequest = 10
      configuration.timeoutIntervalForResource = 20
      let session = URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
      defer { session.invalidateAndCancel() }
      var attachment: UNNotificationAttachment?
      if !Task.isCancelled, !delivery.isFinished, let file = try? await PushImage.download(image.url, session: session) {
        defer { try? FileManager.default.removeItem(at: file) }
        let options = image.clip.map { [UNNotificationAttachmentOptionsThumbnailClippingRectKey: $0.dictionaryRepresentation] }
        attachment = try? UNNotificationAttachment(identifier: "image", url: file, options: options)
      }
      if !Task.isCancelled { delivery.finish(attachment: attachment) }
    }
    lock.unlock()
  }

  override func serviceExtensionTimeWillExpire() {
    lock.lock()
    let work = self.work
    let delivery = self.delivery
    self.work = nil
    self.delivery = nil
    lock.unlock()
    work?.cancel()
    delivery?.finish(attachment: nil)
  }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  nonisolated func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
#endif
