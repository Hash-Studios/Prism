import 'package:Prism/core/updates/code_push_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class _FakeShorebirdUpdater implements ShorebirdUpdater {
  bool available = true;
  UpdateStatus status = UpdateStatus.outdated;
  String? checkedTrack;
  String? downloadedTrack;
  UpdateException? updateError;

  @override
  bool get isAvailable => available;

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    checkedTrack = track?.value;
    return status;
  }

  @override
  Future<void> update({UpdateTrack? track}) async {
    downloadedTrack = track?.value;
    final UpdateException? error = updateError;
    if (error != null) throw error;
  }
}

void main() {
  test('debug builds skip Shorebird initialization and calls', () async {
    final ShorebirdCodePushUpdater updater = ShorebirdCodePushUpdater(track: () => 'staging');

    expect(kReleaseMode, isFalse);
    expect(kProfileMode, isFalse);
    expect(updater.isAvailable, isFalse);
    expect(await updater.currentPatchNumber(), isNull);
    expect(await updater.nextPatchNumber(), isNull);
    expect(await updater.checkForUpdate(), CodePushStatus.unavailable);
    await updater.downloadUpdate();
  });

  test('an unavailable Shorebird updater skips reads, checks, and downloads', () async {
    final _FakeShorebirdUpdater shorebird = _FakeShorebirdUpdater()..available = false;
    int trackReads = 0;
    final ShorebirdCodePushUpdater updater = ShorebirdCodePushUpdater(
      updater: shorebird,
      track: () {
        trackReads++;
        return 'staging';
      },
    );

    expect(updater.isAvailable, isFalse);
    expect(await updater.currentPatchNumber(), isNull);
    expect(await updater.nextPatchNumber(), isNull);
    expect(await updater.checkForUpdate(), CodePushStatus.unavailable);
    await updater.downloadUpdate();

    expect(trackReads, 0);
    expect(shorebird.checkedTrack, isNull);
    expect(shorebird.downloadedTrack, isNull);
  });

  test('download uses the track selected by the preceding update check', () async {
    final _FakeShorebirdUpdater shorebird = _FakeShorebirdUpdater();
    String track = 'staging';
    final ShorebirdCodePushUpdater updater = ShorebirdCodePushUpdater(updater: shorebird, track: () => track);

    expect(await updater.checkForUpdate(), CodePushStatus.outdated);
    track = 'stable';
    await updater.downloadUpdate();

    expect(shorebird.checkedTrack, 'staging');
    expect(shorebird.downloadedTrack, 'staging');
  });

  test('update failures map to the updater failure contract', () async {
    final _FakeShorebirdUpdater shorebird = _FakeShorebirdUpdater()
      ..updateError = const UpdateException(reason: UpdateFailureReason.installFailed, message: 'failed');
    final ShorebirdCodePushUpdater updater = ShorebirdCodePushUpdater(updater: shorebird, track: () => 'stable');

    await expectLater(
      updater.downloadUpdate(),
      throwsA(
        isA<CodePushException>().having(
          (CodePushException error) => error.failure,
          'failure',
          CodePushFailure.installFailed,
        ),
      ),
    );
  });
}
