import Foundation

/// The App Group folder where the Share Extension leaves one shared image for the app to take.
enum ShareInbox {
  static let appGroup = "group.com.hash.prism"
  static let folderName = "shared-inbox"
  static let maxBytes: Int64 = 50 * 1024 * 1024
  static let maxTextLength = 2048

  enum Failure: Error, Equatable {
    case tooLarge
    case unreadable
  }

  static func containerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  static func folder(in container: URL) -> URL {
    container.appendingPathComponent(folderName, isDirectory: true)
  }

  static func newId() -> String { UUID().uuidString.lowercased() }

  static func isValidId(_ id: String) -> Bool {
    id.count == 36 && id.allSatisfy { "0123456789abcdef-".contains($0) }
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
  static func store(fileAt source: URL, ext: String, container: URL, id: String = newId()) throws -> String {
    let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize
    guard let size, size > 0 else { throw Failure.unreadable }
    guard Int64(size) <= maxBytes else { throw Failure.tooLarge }
    let destination = try prepare(id: id, ext: ext, container: container)
    do {
      try FileManager.default.copyItem(at: source, to: destination)
    } catch {
      throw Failure.unreadable
    }
    return id
  }

  static func store(data: Data, ext: String, container: URL, id: String = newId()) throws -> String {
    guard !data.isEmpty else { throw Failure.unreadable }
    guard Int64(data.count) <= maxBytes else { throw Failure.tooLarge }
    let destination = try prepare(id: id, ext: ext, container: container)
    do {
      try data.write(to: destination, options: .atomic)
    } catch {
      throw Failure.unreadable
    }
    return id
  }

  /// The finished file for [id], or nil when the id is malformed or nothing was stored.
  static func file(forId id: String, container: URL) -> URL? {
    guard isValidId(id) else { return nil }
    let entries = (try? FileManager.default.contentsOfDirectory(at: folder(in: container), includingPropertiesForKeys: nil)) ?? []
    return entries.first { $0.deletingPathExtension().lastPathComponent == id && $0.pathExtension != "part" }
  }

  static func openURL(id: String) -> URL? {
    guard isValidId(id) else { return nil }
    return URL(string: "prism://share-in?id=\(id)")
  }

  static func openURL(text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let capped = String(trimmed.prefix(maxTextLength))
    let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    guard let encoded = capped.addingPercentEncoding(withAllowedCharacters: unreserved) else { return nil }
    return URL(string: "prism://share-in?text=\(encoded)")
  }

  private static func prepare(id: String, ext: String, container: URL) throws -> URL {
    guard isValidId(id) else { throw Failure.unreadable }
    let directory = folder(in: container)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      throw Failure.unreadable
    }
    let destination = directory.appendingPathComponent("\(id).\(ext)")
    try? FileManager.default.removeItem(at: destination)
    return destination
  }
}
