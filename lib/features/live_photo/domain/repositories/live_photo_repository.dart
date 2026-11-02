import 'dart:ui' show Color;

import 'package:Prism/features/live_photo/domain/entities/live_export.dart';

abstract class LivePhotoRepository {
  /// Renders [export] from [imageUrl] and saves it to Photos as one Live Photo. [onProgress] gets 0 to 1.
  /// [depthMapUrl] is required for the 3D style. [tint] colours the Shimmer glow.
  Future<LiveExportOutcome> export(
    LiveExport export, {
    required String imageUrl,
    required Color tint,
    required void Function(double fraction) onProgress,
    String? depthMapUrl,
  });

  /// Stops the running export. It then ends with [LiveExportCancelled].
  Future<void> cancel();
}
