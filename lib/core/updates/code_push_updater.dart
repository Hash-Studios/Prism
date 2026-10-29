import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

enum CodePushStatus { upToDate, outdated, restartRequired, unavailable }

/// Why [CodePushUpdater.downloadUpdate] failed.
enum CodePushFailure { downloadFailed, installFailed, unknown }

class CodePushException implements Exception {
  const CodePushException(this.failure);

  final CodePushFailure failure;

  @override
  String toString() => 'CodePushException(${failure.name})';
}

/// Shorebird code push as the app sees it. Patch numbers are null when the release runs without a patch.
abstract interface class CodePushUpdater {
  bool get isAvailable;

  Future<int?> currentPatchNumber();

  /// The patch the next launch boots. Equals [currentPatchNumber] until a download or a rollback.
  Future<int?> nextPatchNumber();

  /// Also uninstalls the current patch when the server rolled it back.
  Future<CodePushStatus> checkForUpdate();

  /// Throws [CodePushException].
  Future<void> downloadUpdate();
}

class ShorebirdCodePushUpdater implements CodePushUpdater {
  ShorebirdCodePushUpdater({required String Function() track, ShorebirdUpdater? updater})
    : _track = track,
      _providedUpdater = updater;

  final String Function() _track;
  final ShorebirdUpdater? _providedUpdater;
  String? _downloadTrack;

  // Only `shorebird release` builds carry the updater. Debug and profile builds skip its FFI probe and console banner.
  late final ShorebirdUpdater? _updater = _providedUpdater ?? (kReleaseMode ? ShorebirdUpdater() : null);

  @override
  bool get isAvailable => _updater?.isAvailable ?? false;

  @override
  Future<int?> currentPatchNumber() async {
    final ShorebirdUpdater? updater = _updater;
    if (updater == null || !updater.isAvailable) return null;
    return (await updater.readCurrentPatch())?.number;
  }

  @override
  Future<int?> nextPatchNumber() async {
    final ShorebirdUpdater? updater = _updater;
    if (updater == null || !updater.isAvailable) return null;
    return (await updater.readNextPatch())?.number;
  }

  @override
  Future<CodePushStatus> checkForUpdate() async {
    final ShorebirdUpdater? updater = _updater;
    if (updater == null || !updater.isAvailable) return CodePushStatus.unavailable;
    final String track = _track();
    try {
      final UpdateStatus status = await updater.checkForUpdate(track: UpdateTrack(track));
      _downloadTrack = status == UpdateStatus.outdated ? track : null;
      return switch (status) {
        UpdateStatus.upToDate => CodePushStatus.upToDate,
        UpdateStatus.outdated => CodePushStatus.outdated,
        UpdateStatus.restartRequired => CodePushStatus.restartRequired,
        UpdateStatus.unavailable => CodePushStatus.unavailable,
      };
    } catch (_) {
      _downloadTrack = null;
      rethrow;
    }
  }

  @override
  Future<void> downloadUpdate() async {
    final ShorebirdUpdater? updater = _updater;
    if (updater == null || !updater.isAvailable) return;
    final String track = _downloadTrack ?? _track();
    _downloadTrack = null;
    try {
      await updater.update(track: UpdateTrack(track));
    } on UpdateException catch (error) {
      throw CodePushException(switch (error.reason) {
        UpdateFailureReason.downloadFailed => CodePushFailure.downloadFailed,
        UpdateFailureReason.installFailed => CodePushFailure.installFailed,
        UpdateFailureReason.noUpdate || UpdateFailureReason.unknown => CodePushFailure.unknown,
      });
    }
  }
}
