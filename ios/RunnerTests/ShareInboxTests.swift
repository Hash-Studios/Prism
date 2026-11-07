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

  private func storeImage(in container: URL, ext: String = "png") throws -> String {
    let source = container.appendingPathComponent("fixture.png")
    try Data([1]).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    return try ShareInbox.store(fileAt: source, ext: ext, container: container)
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

  @Test func malformedUuidIsRejected() {
    #expect(!ShareInbox.isValidId(String(repeating: "-", count: 36)))
  }

  @Test func textLimitCountsUtf16WithoutSplittingEmoji() throws {
    let text = String(repeating: "a", count: 2047) + "😀tail"
    let url = try #require(ShareInbox.openURL(text: text))
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value)
    #expect(query == String(repeating: "a", count: 2047))
  }

  @Test func storeRejectsExtensionTraversal() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    #expect(throws: ShareInbox.Failure.unreadable) {
      try storeImage(in: container, ext: "png/../../outside")
    }
  }

  @Test func nativeTakeRejectsInvalidFileTypesAndDeletesOnlyTheLink() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let inbox = ShareInbox.folder(in: container)
    try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
    let id = ShareInbox.newId()
    let image = inbox.appendingPathComponent("\(id).png")
    let outside = container.appendingPathComponent("outside.png")
    try Data([1]).write(to: outside)
    try FileManager.default.createSymbolicLink(at: image, withDestinationURL: outside)
    #expect(throws: ShareInbox.Failure.unreadable) { try ShareInbox.takeFile(forId: id, container: container) }
    #expect(FileManager.default.fileExists(atPath: outside.path))
    #expect(!FileManager.default.fileExists(atPath: image.path))
    try FileManager.default.createDirectory(at: image, withIntermediateDirectories: false)
    #expect(throws: ShareInbox.Failure.unreadable) { try ShareInbox.takeFile(forId: id, container: container) }
    #expect(!FileManager.default.fileExists(atPath: image.path))
    try Data().write(to: image)
    #expect(throws: ShareInbox.Failure.unreadable) { try ShareInbox.takeFile(forId: id, container: container) }
    #expect(!FileManager.default.fileExists(atPath: image.path))
    try Data([1]).write(to: inbox.appendingPathComponent("\(id).txt"))
    #expect(throws: ShareInbox.Failure.unreadable) { try ShareInbox.takeFile(forId: id, container: container) }
  }

  @Test func growingSourceCannotBypassCopyLimit() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let source = container.appendingPathComponent("growing.png")
    try Data([1]).write(to: source)
    var grew = false
    #expect(throws: ShareInbox.Failure.tooLarge) {
      try ShareInbox.store(fileAt: source, ext: "png", container: container, isCanceled: {
        if !grew {
          let handle = try! FileHandle(forWritingTo: source)
          try! handle.truncate(atOffset: UInt64(ShareInbox.maxBytes + 1))
          try! handle.close()
          grew = true
        }
        return false
      })
    }
    let entries = try FileManager.default.contentsOfDirectory(atPath: ShareInbox.folder(in: container).path)
    #expect(entries.isEmpty)
  }

  @Test func canceledCopyLeavesNoPartialOrFinishedFile() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let source = container.appendingPathComponent("source.png")
    try Data(repeating: 1, count: 128 * 1024).write(to: source)
    var checks = 0
    #expect(throws: ShareInbox.Failure.unreadable) {
      try ShareInbox.store(fileAt: source, ext: "png", container: container, isCanceled: {
        checks += 1
        return checks >= 2
      })
    }
    let entries = try FileManager.default.contentsOfDirectory(atPath: ShareInbox.folder(in: container).path)
    #expect(entries.isEmpty)
  }

  @Test func sweepRemovesOldPartialAndFinalFilesButKeepsFreshCopies() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let id = try storeImage(in: container)
    let final = try #require(ShareInbox.file(forId: id, container: container))
    let part = final.deletingPathExtension().appendingPathExtension("part")
    let freshPart = ShareInbox.folder(in: container).appendingPathComponent("fresh.part")
    try Data([1]).write(to: part)
    try Data([1]).write(to: freshPart)
    let old = Date(timeIntervalSinceNow: -25 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: final.path)
    try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: part.path)
    ShareInbox.sweep(container: container)
    #expect(!FileManager.default.fileExists(atPath: final.path))
    #expect(!FileManager.default.fileExists(atPath: part.path))
    #expect(FileManager.default.fileExists(atPath: freshPart.path))
  }

  @Test func copyingOldPhotoStartsANewRetentionWindow() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let source = container.appendingPathComponent("old.png")
    try Data([1]).write(to: source)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: source.path)
    let id = try ShareInbox.store(fileAt: source, ext: "png", container: container)
    ShareInbox.sweep(container: container)
    #expect(ShareInbox.file(forId: id, container: container) != nil)
  }

  @Test func requestCompletesOnlyOnceAndSignalsLateCopiesToCancel() {
    let request = ShareInboxRequest()
    #expect(!request.isFinished)
    #expect(request.finish())
    #expect(request.isFinished)
    #expect(!request.finish())
  }

  @Test @MainActor func requestTimesOutWhenProviderNeverCallsBack() async {
    let request = ShareInboxRequest()
    let didFinish = await withCheckedContinuation { continuation in
      request.startTimeout(after: 0.01) { continuation.resume(returning: request.finish()) }
    }
    #expect(didFinish)
    #expect(request.isFinished)
    #expect(!request.finish())
  }

  @Test func lateProviderResultDeletesItsCompletedFile() throws {
    let container = makeContainer()
    defer { try? FileManager.default.removeItem(at: container) }
    let request = ShareInboxRequest()
    let id = try storeImage(in: container)
    let file = try #require(ShareInbox.file(forId: id, container: container))
    #expect(request.finish())
    #expect(!request.finish(discardingIfLate: file))
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }
}
