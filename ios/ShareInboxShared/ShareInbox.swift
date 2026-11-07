import Foundation

/// The App Group folder where the Share Extension leaves one shared image for the app to take.
enum ShareInbox {
  static let appGroup = "group.com.hash.prism"
  static let folderName = "shared-inbox"
  static let maxBytes: Int64 = 50 * 1024 * 1024
  static let maxTextLength = 2048
  private static let imageExtensions: Set<String> = ["jpg", "png", "webp", "heic", "heif", "gif"]

  enum Failure: Error, Equatable {
    case tooLarge
    case unreadable
    case missing
  }

  static func containerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  static func folder(in container: URL) -> URL {
    container.appendingPathComponent(folderName, isDirectory: true)
  }

  static func newId() -> String { UUID().uuidString.lowercased() }

  static func isValidId(_ id: String) -> Bool {
    UUID(uuidString: id)?.uuidString.lowercased() == id
  }

  static func fileExtension(forTypeIdentifier type: String) -> String {
    switch type {
    case "public.png": return "png"
    case "org.webmproject.webp": return "webp"
    case "public.heic": return "heic"
    case "public.heif": return "heif"
    case "com.compuserve.gif": return "gif"
    default: return "jpg"
    }
  }

  /// Copies the file without decoding it, so a large photo costs the extension almost no memory.
  static func store(
    fileAt source: URL, ext: String, container: URL, id: String = newId(), isCanceled: () -> Bool = { false }
  ) throws -> String {
    guard source.isFileURL,
      let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
      values.isRegularFile == true, values.isSymbolicLink != true,
      let size = values.fileSize, size > 0 else { throw Failure.unreadable }
    guard Int64(size) <= maxBytes else { throw Failure.tooLarge }
    let destination = try prepare(id: id, ext: ext, container: container)
    let part = destination.deletingPathExtension().appendingPathExtension("part")
    defer { try? FileManager.default.removeItem(at: part) }
    do {
      let input = try FileHandle(forReadingFrom: source)
      defer { try? input.close() }
      try Data().write(to: part, options: .withoutOverwriting)
      let output = try FileHandle(forWritingTo: part)
      defer { try? output.close() }
      var copied: Int64 = 0
      while true {
        guard !isCanceled() else { throw Failure.unreadable }
        let bytes = try input.read(upToCount: 64 * 1024) ?? Data()
        if bytes.isEmpty { break }
        copied += Int64(bytes.count)
        guard copied <= maxBytes else { throw Failure.tooLarge }
        try output.write(contentsOf: bytes)
      }
      guard copied > 0, !isCanceled() else { throw Failure.unreadable }
      try output.close()
      try FileManager.default.moveItem(at: part, to: destination)
    } catch let failure as Failure {
      throw failure
    } catch {
      throw Failure.unreadable
    }
    return id
  }

  /// The finished file for [id], or nil when the id is malformed or nothing was stored.
  static func file(forId id: String, container: URL) -> URL? {
    try? takeFile(forId: id, container: container)
  }

  static func takeFile(forId id: String, container: URL) throws -> URL {
    guard isValidId(id) else { throw Failure.unreadable }
    let entries = (try? FileManager.default.contentsOfDirectory(at: folder(in: container), includingPropertiesForKeys: nil)) ?? []
    guard let file = entries.first(where: { $0.deletingPathExtension().lastPathComponent == id && $0.pathExtension != "part" })
      else { throw Failure.missing }
    do {
      let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard imageExtensions.contains(file.pathExtension), values.isRegularFile == true, values.isSymbolicLink != true,
        let size = values.fileSize, size > 0 else { throw Failure.unreadable }
      guard Int64(size) <= maxBytes else { throw Failure.tooLarge }
      return file
    } catch {
      try? FileManager.default.removeItem(at: file)
      throw (error as? Failure) ?? Failure.unreadable
    }
  }

  /// A fresh partial may belong to another extension process. All transfers time out within 30 seconds.
  static func sweep(container: URL, now: Date = Date()) {
    let entries = (try? FileManager.default.contentsOfDirectory(
      at: folder(in: container), includingPropertiesForKeys: [.contentModificationDateKey]
    )) ?? []
    for file in entries {
      guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { continue }
      let age = now.timeIntervalSince(modified)
      if age > 24 * 60 * 60 || (file.pathExtension == "part" && age > 60) {
        try? FileManager.default.removeItem(at: file)
      }
    }
  }

  private static let pendingLinkName = "pending-link"

  /// Leaves [url] for the app, which takes it when it is ready. The system can drop a URL it hands over while the
  /// app starts, so the app does not depend on that delivery.
  static func storePendingLink(_ url: URL, container: URL) {
    let directory = folder(in: container)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? Data(url.absoluteString.utf8).write(to: directory.appendingPathComponent(pendingLinkName), options: .atomic)
  }

  /// The share link the extension left, once. Anything that is not a share link is deleted and ignored.
  static func takePendingLink(container: URL) -> String? {
    let file = folder(in: container).appendingPathComponent(pendingLinkName)
    guard let data = try? Data(contentsOf: file) else { return nil }
    try? FileManager.default.removeItem(at: file)
    guard let link = String(data: data, encoding: .utf8), link.hasPrefix("prism://share-in?") else { return nil }
    return link
  }

  static func openURL(id: String) -> URL? {
    guard isValidId(id) else { return nil }
    return URL(string: "prism://share-in?id=\(id)")
  }

  static func openURL(text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    var capped = ""
    var length = 0
    for scalar in trimmed.unicodeScalars {
      let units = scalar.value > 0xFFFF ? 2 : 1
      if length + units > maxTextLength { break }
      capped.unicodeScalars.append(scalar)
      length += units
    }
    let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    guard let encoded = capped.addingPercentEncoding(withAllowedCharacters: unreserved) else { return nil }
    return URL(string: "prism://share-in?text=\(encoded)")
  }

  private static func prepare(id: String, ext: String, container: URL) throws -> URL {
    guard isValidId(id), imageExtensions.contains(ext) else { throw Failure.unreadable }
    let directory = folder(in: container)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      throw Failure.unreadable
    }
    let destination = directory.appendingPathComponent("\(id).\(ext)")
    guard !FileManager.default.fileExists(atPath: destination.path) else { throw Failure.unreadable }
    return destination
  }
}

/// The provider callback and the timeout race to finish one extension request.
final class ShareInboxRequest {
  private let lock = NSLock()
  private var finished = false
  private var deadline: DispatchWorkItem?

  func startTimeout(after seconds: TimeInterval = 30, onTimeout: @escaping () -> Void) {
    let work = DispatchWorkItem(block: onTimeout)
    lock.lock()
    guard !finished else { lock.unlock(); return }
    deadline?.cancel()
    deadline = work
    lock.unlock()
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
  }

  var isFinished: Bool {
    lock.lock()
    defer { lock.unlock() }
    return finished
  }

  func finish(discardingIfLate file: URL? = nil) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard !finished else {
      if let file { try? FileManager.default.removeItem(at: file) }
      return false
    }
    finished = true
    deadline?.cancel()
    return true
  }
}
