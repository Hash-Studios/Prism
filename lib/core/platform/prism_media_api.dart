import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';

/// [PrismMediaHostApi] that tries a call once more when Android answers `ENGINE_DETACHED`.
///
/// A new wallpaper changes the system colours, and Android relaunches MainActivity. That closes the media API
/// that held the call, but Dart keeps running, so the second try reaches the new one. Android sends this code
/// only before it saves, deletes, or reports anything, so a second try cannot save a file twice.
class PrismMediaApi extends PrismMediaHostApi {
  static const String engineDetached = 'ENGINE_DETACHED';

  @override
  Future<OperationResult> saveMedia(SaveMediaRequest request) =>
      _retry(() => super.saveMedia(request), (result) => result.errorCode);

  @override
  Future<OperationResult> enqueueDownload(DownloadRequest request) =>
      _retry(() => super.enqueueDownload(request), (result) => result.errorCode);

  @override
  Future<DownloadItemsResult> listDownloads() => _retry(super.listDownloads, (result) => result.errorCode);

  @override
  Future<OperationResult> clearDownloads() => _retry(super.clearDownloads, (result) => result.errorCode);

  @override
  Future<OperationResult> deleteDownload(String path) =>
      _retry(() => super.deleteDownload(path), (result) => result.errorCode);

  static Future<T> _retry<T>(Future<T> Function() call, String? Function(T result) errorCode) async {
    final T result = await call();
    return errorCode(result) == engineDetached ? call() : result;
  }
}
