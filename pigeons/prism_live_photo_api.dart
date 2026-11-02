import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(swiftOptions: SwiftOptions(errorClassName: 'PrismLivePhotoError')))
@HostApi()
abstract class PrismLivePhotoHostApi {
  /// Asks for Photos add-only access, renders the clip and the key photo, saves them as one Live Photo and reads the
  /// asset back when the app may read the library. Progress goes to [PrismLivePhotoFlutterApi].
  @async
  LivePhotoExportResult exportLivePhoto(LivePhotoExportRequest request);

  /// Stops the export with this id. That export then returns [LivePhotoExportStatus.cancelled].
  void cancelLivePhotoExport(String exportId);
}

@FlutterApi()
abstract class PrismLivePhotoFlutterApi {
  /// [fraction] goes from 0 to 1 while the frames render. Saving follows at 1.
  void onLivePhotoExportProgress(String exportId, double fraction);
}

enum LivePhotoStyle { drift, breathe, shimmer, depth }

class LivePhotoExportRequest {
  final String exportId;

  /// A JPEG already cropped to the screen aspect.
  final String photoPath;

  /// The depth map, cropped like the photo. Required for [LivePhotoStyle.depth].
  final String? depthPath;
  final LivePhotoStyle style;
  final int widthPx;
  final int heightPx;
  final int durationMs;
  final int framesPerSecond;

  /// The glow colour of [LivePhotoStyle.shimmer], 0xAARRGGBB.
  final int tint;
  final int timeoutMs;

  LivePhotoExportRequest({
    required this.exportId,
    required this.photoPath,
    this.depthPath,
    required this.style,
    required this.widthPx,
    required this.heightPx,
    required this.durationMs,
    required this.framesPerSecond,
    required this.tint,
    required this.timeoutMs,
  });
}

enum LivePhotoExportStatus { saved, cancelled, permissionDenied, permissionRestricted, timedOut, failed }

class LivePhotoExportResult {
  final LivePhotoExportStatus status;

  /// For [LivePhotoExportStatus.failed]: `invalid-request`, `render-failed`, `encode-failed`, `save-failed` or
  /// `not-live`.
  final String? errorCode;
  final String? assetId;

  /// True when the saved asset reads back as a Live Photo. Null when the app may not read the library.
  final bool? verifiedLive;

  LivePhotoExportResult({required this.status, this.errorCode, this.assetId, this.verifiedLive});
}
