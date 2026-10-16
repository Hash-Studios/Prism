import Foundation

enum PrismShortcutImageKind: Equatable, Sendable {
  case jpeg
  case png

  init?(data: Data) {
    let header = [UInt8](data.prefix(8))
    if header.starts(with: [0xFF, 0xD8, 0xFF]) {
      self = .jpeg
    } else if header == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
      self = .png
    } else {
      return nil
    }
  }

  var filenameExtension: String {
    switch self {
    case .jpeg: return "jpg"
    case .png: return "png"
    }
  }
}
