import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PrismMediaHostApi {
  OperationResult saveMedia(SaveMediaRequest request);
  OperationResult enqueueDownload(DownloadRequest request);
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

  DownloadRequest({
    required this.link,
    required this.filenameWithoutExtension,
  });
}

class OperationResult {
  final bool success;
  final String? errorCode;
  final String? message;

  OperationResult({
    required this.success,
    this.errorCode,
    this.message,
  });
}

enum SaveMediaKind {
  wallpaper,
  setup,
}
