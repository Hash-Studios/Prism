import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PrismMediaHostApi {
  @async
  OperationResult saveMedia(SaveMediaRequest request);
  @async
  OperationResult enqueueDownload(DownloadRequest request);
  @async
  OperationResult prepareAlbumSave(String album);
  @async
  DownloadItemsResult listDownloads();
  @async
  OperationResult clearDownloads();
  @async
  OperationResult deleteDownload(String path);
}

class SaveMediaRequest {
  final String link;
  final bool isLocalFile;
  final SaveMediaKind kind;

  SaveMediaRequest({
    required this.link,
    required this.isLocalFile,
    required this.kind,
  });
}

class DownloadRequest {
  final String link;
  final String filenameWithoutExtension;
  final bool isLocalFile;
  final String? album;

  DownloadRequest({
    required this.link,
    required this.filenameWithoutExtension,
    required this.isLocalFile,
    this.album,
  });
}

class OperationResult {
  final bool success;
  final String? errorCode;
  final String? message;

  OperationResult({required this.success, this.errorCode, this.message});
}

class DownloadItemsResult {
  final bool success;
  final List<String> items;
  final String? errorCode;
  final String? message;

  DownloadItemsResult({
    required this.success,
    required this.items,
    this.errorCode,
    this.message,
  });
}

enum SaveMediaKind { wallpaper, setup }
