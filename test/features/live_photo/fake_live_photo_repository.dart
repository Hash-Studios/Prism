import 'dart:async';
import 'dart:ui' show Color;

import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/domain/repositories/live_photo_repository.dart';

class FakeLivePhotoRepository implements LivePhotoRepository {
  final List<LiveExport> exports = <LiveExport>[];
  final List<String> imageUrls = <String>[];
  final List<String?> depthMapUrls = <String?>[];
  int cancelCount = 0;

  void Function(double fraction)? lastOnProgress;

  Completer<LiveExportOutcome>? _pending;

  @override
  Future<LiveExportOutcome> export(
    LiveExport export, {
    required String imageUrl,
    required Color tint,
    required void Function(double fraction) onProgress,
    String? depthMapUrl,
  }) {
    exports.add(export);
    imageUrls.add(imageUrl);
    depthMapUrls.add(depthMapUrl);
    lastOnProgress = onProgress;
    final Completer<LiveExportOutcome> completer = Completer<LiveExportOutcome>();
    _pending = completer;
    return completer.future;
  }

  void complete(LiveExportOutcome outcome) {
    _pending!.complete(outcome);
    _pending = null;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    final Completer<LiveExportOutcome>? pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(const LiveExportCancelled());
  }
}
