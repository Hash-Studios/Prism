import 'package:Prism/features/live_wallpaper/data/live_apply_outcome_mapper.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter_test/flutter_test.dart';

aw.WallpaperOperationResult _result(aw.WallpaperOperationStatus status, {String? code}) {
  return aw.WallpaperOperationResult(status: status, requestedTarget: aw.WallpaperTarget.home, errorCode: code);
}

void main() {
  test('preview states ask the user to confirm in the system preview', () {
    for (final aw.WallpaperOperationStatus status in <aw.WallpaperOperationStatus>[
      aw.WallpaperOperationStatus.previewOpened,
      aw.WallpaperOperationStatus.awaitingUserConfirmation,
    ]) {
      final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(_result(status));
      expect(outcome.status, LiveApplyStatus.confirmInPreview);
      expect(outcome.message, 'Confirm in the system preview.');
      expect(outcome.isError, isFalse);
    }
  });

  test('applied is a success', () {
    final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.applied));
    expect(outcome.status, LiveApplyStatus.applied);
    expect(outcome.isError, isFalse);
  });

  test('cancelled is silent', () {
    final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.cancelled));
    expect(outcome.status, LiveApplyStatus.cancelled);
    expect(outcome.message, isEmpty);
  });

  test('unsupported and foreground errors are clear', () {
    expect(
      liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.unsupported)).status,
      LiveApplyStatus.unsupported,
    );
    final LiveApplyOutcome foreground = liveApplyOutcomeFromResult(
      _result(aw.WallpaperOperationStatus.foregroundRequired),
    );
    expect(foreground.isError, isTrue);
    expect(foreground.message, 'Keep Prism open and try again.');
  });

  test('plugin error codes map to plain messages', () {
    String message(String code) =>
        liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.failed, code: code)).message;
    expect(message('source-too-large'), 'That file is too large for a live wallpaper.');
    expect(message('invalid-video'), contains('Try another clip'));
    expect(message('shader-compilation-failed'), contains('Try another one'));
    expect(message('out-of-memory'), contains('Not enough memory'));
    expect(message('something-new'), "Couldn't set the live wallpaper. Try again.");
    expect(
      liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.failed)).message,
      "Couldn't set the live wallpaper. Try again.",
    );
  });
}
