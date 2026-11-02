import Foundation

@MainActor
final class PrismLivePhotoHostApiImpl: @preconcurrency PrismLivePhotoHostApi {
  private let flutterApi: PrismLivePhotoFlutterApiProtocol
  private var exports: [String: Task<Void, Never>] = [:]

  init(flutterApi: PrismLivePhotoFlutterApiProtocol) {
    self.flutterApi = flutterApi
  }

  func exportLivePhoto(
    request: LivePhotoExportRequest,
    completion: @escaping (Result<LivePhotoExportResult, Error>) -> Void
  ) {
    for export in exports.values { export.cancel() }
    let id = request.exportId
    exports[id] = Task { [weak self] in
      let result = await PrismLivePhotoExporter.export(request) { fraction in
        Task { @MainActor [weak self] in self?.report(id, fraction) }
      }
      completion(.success(result))
      self?.exports[id] = nil
    }
  }

  private func report(_ id: String, _ fraction: Double) {
    guard exports[id] != nil else { return }
    flutterApi.onLivePhotoExportProgress(exportId: id, fraction: fraction) { _ in }
  }

  func cancelLivePhotoExport(exportId: String) throws {
    exports[exportId]?.cancel()
  }
}
