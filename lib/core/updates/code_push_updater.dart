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
  ShorebirdCodePushUpdater({required String Function() track}) : _track = track;

  final String Function() _track;

  // Only `shorebird release` builds carry the updater. Debug and profile builds skip its FFI probe and console banner.
  late final ShorebirdUpdater? _updater = kReleaseMode ? ShorebirdUpdater() : null;

  @override
  bool get isAvailable => _updater?.isAvailable ?? false;

  @override
  Future<int?> currentPatchNumber() async => (await _updater?.readCurrentPatch())?.number;

  @override
  Future<int?> nextPatchNumber() async => (await _updater?.readNextPatch())?.number;

  @override
  Future<CodePushStatus> checkForUpdate() async {
    final ShorebirdUpdater? updater = _updater;
    if (updater == null) return CodePushStatus.unavailable;
    return switch (await updater.checkForUpdate(track: UpdateTrack(_track()))) {
      UpdateStatus.upToDate => CodePushStatus.upToDate,
      UpdateStatus.outdated => CodePushStatus.outdated,
      UpdateStatus.restartRequired => CodePushStatus.restartRequired,
      UpdateStatus.unavailable => CodePushStatus.unavailable,
    };
  }

  @override
  Future<void> downloadUpdate() async {
    try {
      await _updater?.update(track: UpdateTrack(_track()));
    } on UpdateException catch (error) {
      throw CodePushException(switch (error.reason) {
        UpdateFailureReason.downloadFailed => CodePushFailure.downloadFailed,
        UpdateFailureReason.installFailed => CodePushFailure.installFailed,
        UpdateFailureReason.noUpdate || UpdateFailureReason.unknown => CodePushFailure.unknown,
      });
    }
  }
}
