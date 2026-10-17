import Foundation

enum PrismShortcutLocalFileResolver {
  static func resolve(path: String, roots: [URL], maximumBytes: Int) -> URL? {
    guard !path.isEmpty, !path.hasPrefix("/") else { return nil }
    let relative = URL(fileURLWithPath: path).standardizedFileURL
    guard !relative.pathComponents.contains("..") else { return nil }
    for root in roots {
      let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
      let candidate = root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
      let rootPath = canonicalRoot.path.hasSuffix("/") ? canonicalRoot.path : canonicalRoot.path + "/"
      guard candidate.path.hasPrefix(rootPath),
        let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
        values.isRegularFile == true,
        let fileSize = values.fileSize,
        fileSize > 0,
        fileSize <= maximumBytes,
        let handle = try? FileHandle(forReadingFrom: candidate)
      else { continue }
      let header = try? handle.read(upToCount: 16)
      try? handle.close()
      if let header, isImage(header) { return candidate }
    }
    return nil
  }

  private static func isImage(_ data: Data) -> Bool {
    let bytes = [UInt8](data)
    return (bytes.count >= 3 && bytes[0...2].elementsEqual([0xff, 0xd8, 0xff])) ||
      (bytes.count >= 8 && bytes[0...7].elementsEqual([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) ||
      (bytes.count >= 6 && String(decoding: bytes[0..<4], as: UTF8.self) == "GIF8") ||
      (bytes.count >= 12 && String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF" &&
        String(decoding: bytes[8..<12], as: UTF8.self) == "WEBP")
  }
}
