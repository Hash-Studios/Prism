import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/live_wallpaper/data/live_apply_outcome_mapper.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter_test/flutter_test.dart';

aw.WallpaperOperationResult _result(
  aw.WallpaperOperationStatus status, {
  String? code,
  aw.WallpaperTarget requestedTarget = aw.WallpaperTarget.home,
  aw.WallpaperTarget? effectiveTarget,
}) {
  return aw.WallpaperOperationResult(
    status: status,
    requestedTarget: requestedTarget,
    errorCode: code,
    effectiveTarget: effectiveTarget,
  );
}

void main() {
  test('a preview for home that the platform widens to both screens is a fallback', () {
    final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(
      _result(aw.WallpaperOperationStatus.previewOpened, effectiveTarget: aw.WallpaperTarget.both),
    );
    expect(outcome.status, LiveApplyStatus.confirmInPreview);
    expect(outcome.target, WallpaperTarget.home);
    expect(outcome.fallback, isTrue);
  });

  test('a preview for both screens that lands on both is not a fallback', () {
    final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(
      _result(
        aw.WallpaperOperationStatus.awaitingUserConfirmation,
        requestedTarget: aw.WallpaperTarget.both,
        effectiveTarget: aw.WallpaperTarget.both,
      ),
    );
    expect(outcome.target, WallpaperTarget.both);
    expect(outcome.fallback, isFalse);
  });

  test('a preview for lock that lands on lock is not a fallback', () {
    final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(
      _result(
        aw.WallpaperOperationStatus.previewOpened,
        requestedTarget: aw.WallpaperTarget.lock,
        effectiveTarget: aw.WallpaperTarget.lock,
      ),
    );
    expect(outcome.target, WallpaperTarget.lock);
    expect(outcome.fallback, isFalse);
  });

  test('a preview without an effective target is not a fallback', () {
    final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.previewOpened));
    expect(outcome.fallback, isFalse);
  });

  test('preview states ask the user to confirm in the system preview', () {
    for (final aw.WallpaperOperationStatus status in <aw.WallpaperOperationStatus>[
      aw.WallpaperOperationStatus.previewOpened,
      aw.WallpaperOperationStatus.awaitingUserConfirmation,
    ]) {
      final LiveApplyOutcome outcome = liveApplyOutcomeFromResult(_result(status));
      expect(outcome.status, LiveApplyStatus.confirmInPreview);
      expect(outcome.failure, isNull);
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
    expect(outcome.failure, isNull);
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
    expect(foreground.failure, LiveApplyFailure.keepPrismOpen);
  });

  test('plugin error codes map to typed failures', () {
    LiveApplyFailure? failure(String code) =>
        liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.failed, code: code)).failure;
    expect(failure('source-too-large'), LiveApplyFailure.fileTooLarge);
    expect(failure('invalid-video'), LiveApplyFailure.invalidVideo);
    expect(failure('shader-compilation-failed'), LiveApplyFailure.styleUnavailable);
    expect(failure('out-of-memory'), LiveApplyFailure.outOfMemory);
    expect(failure('something-new'), LiveApplyFailure.setFailed);
    expect(liveApplyOutcomeFromResult(_result(aw.WallpaperOperationStatus.failed)).failure, LiveApplyFailure.setFailed);
  });
}
