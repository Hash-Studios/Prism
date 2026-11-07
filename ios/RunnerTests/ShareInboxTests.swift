import Foundation
import Testing

#if canImport(Runner)
@testable import Runner
#endif

struct ShareInboxTests {
  private func makeContainer() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test func storeCopiesFileIntoInboxAndKeepsSource() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let source = container.appendingPathComponent("source.png")
    let bytes = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
    try bytes.write(to: source)

    let id = try ShareInbox.store(fileAt: source, ext: "png", container: container)

    #expect(ShareInbox.isValidId(id))
    let stored = try #require(ShareInbox.file(forId: id, container: container))
    #expect(stored.lastPathComponent == "\(id).png")
    #expect(stored.deletingLastPathComponent().lastPathComponent == ShareInbox.folderName)
    let storedBytes = try Data(contentsOf: stored)
    #expect(storedBytes == bytes)
    #expect(FileManager.default.fileExists(atPath: source.path))
  }

  @Test func storeRefusesFileLargerThanLimitAndLeavesNoFile() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let source = container.appendingPathComponent("big.png")
    FileManager.default.createFile(atPath: source.path, contents: nil)
    let handle = try FileHandle(forWritingTo: source)
    try handle.truncate(atOffset: UInt64(ShareInbox.maxBytes + 1))
    try handle.close()

    #expect(throws: ShareInbox.Failure.tooLarge) {
      try ShareInbox.store(fileAt: source, ext: "png", container: container)
    }
    let entries = (try? FileManager.default.contentsOfDirectory(atPath: ShareInbox.folder(in: container).path)) ?? []
    #expect(entries.isEmpty)
  }

  @Test func storeRefusesEmptyFile() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let source = container.appendingPathComponent("empty.png")
    FileManager.default.createFile(atPath: source.path, contents: Data())

    #expect(throws: ShareInbox.Failure.unreadable) {
      try ShareInbox.store(fileAt: source, ext: "png", container: container)
    }
  }

  @Test func fileForIdRejectsTraversalUppercaseAndPartialFiles() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let inbox = ShareInbox.folder(in: container)
    try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

    let partialId = ShareInbox.newId()
    try Data([1, 2, 3]).write(to: inbox.appendingPathComponent("\(partialId).part"))

    #expect(ShareInbox.file(forId: "../etc", container: container) == nil)
    #expect(ShareInbox.file(forId: ShareInbox.newId().uppercased(), container: container) == nil)
    #expect(ShareInbox.file(forId: partialId, container: container) == nil)
  }

  @Test func openURLForIdAcceptsValidIdOnly() {
    let id = ShareInbox.newId()

    #expect(ShareInbox.openURL(id: id)?.absoluteString == "prism://share-in?id=\(id)")
    #expect(ShareInbox.openURL(id: "../etc") == nil)
  }

  @Test func openURLForTextEncodesQueryValue() {
    let url = ShareInbox.openURL(text: "https://example.com/a?b=1&c=d+e")

    #expect(url?.absoluteString == "prism://share-in?text=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1%26c%3Dd%2Be")
  }

  @Test func openURLForTextKeepsAtMostMaxLength() throws {
    let text = String(repeating: "a", count: 5000)
    let url = try #require(ShareInbox.openURL(text: text))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let value = try #require(components.queryItems?.first(where: { $0.name == "text" })?.value)

    #expect(value.count == 2048)
  }
}
