import 'dart:async';

import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/updates/code_push_updater.dart';
import 'package:flutter/foundation.dart';

typedef StoreRelease = ({String version, String build});

/// The patch that the next launch boots, for one store release. Patch 0 is the release with no patch, where a
/// rollback of the only patch lands.
@immutable
class PendingRestart {
  const PendingRestart({required this.version, required this.build, required this.patchNumber});

  final String version;
  final String build;
  final int patchNumber;

  String get key => '$version+$build#$patchNumber';

  @override
  bool operator ==(Object other) => other is PendingRestart && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Checks for Shorebird patches and downloads them in the background. A downloaded patch, or a rollback, applies on
/// the next launch. [announcement] holds the restart the user was not told about yet.
class OtaUpdateController {
  OtaUpdateController({
    required CodePushUpdater updater,
    required SettingsLocalDataSource settings,
    required AppAnalytics analytics,
    required StoreRelease Function() release,
    void Function(int patchNumber)? tagPatch,
    DateTime Function() now = DateTime.now,
    this.cooldown = const Duration(minutes: 15),
    this.checkTimeout = const Duration(seconds: 30),
    this.downloadTimeout = const Duration(minutes: 5),
  }) : _updater = updater,
       _settings = settings,
       _analytics = analytics,
       _release = release,
       _tagPatch = tagPatch,
       _now = now;

  static const String trackKey = 'ota.track';
  static const String pendingKey = 'ota.pending';
  static const String announcedKey = 'ota.announced';
  static const String bootedKey = 'ota.booted';

  final CodePushUpdater _updater;
  final SettingsLocalDataSource _settings;
  final AppAnalytics _analytics;
  final StoreRelease Function() _release;
  final void Function(int patchNumber)? _tagPatch;
  final DateTime Function() _now;
  final Duration cooldown;
  final Duration checkTimeout;
  final Duration downloadTimeout;

  final ValueNotifier<PendingRestart?> announcement = ValueNotifier<PendingRestart?>(null);

  Future<void>? _running;
  Future<void>? _launchRecording;
  Completer<void>? _updaterCallsDrained;
  int _outstandingUpdaterCalls = 0;
  bool _checkSettled = false;
  bool _launchRecordingSettled = false;
  DateTime? _lastCheck;

  /// Once per launch: tags Sentry with the running patch and reports a patch that runs for the first time.
  Future<void> recordLaunch() {
    final Future<void>? recording = _launchRecording;
    if (recording != null) return recording;
    final Future<void> newRecording = _recordLaunch().whenComplete(() => _launchRecordingSettled = true);
    return _launchRecording = newRecording;
  }

  Future<void> _recordLaunch() async {
    if (!_updater.isAvailable) return;
    try {
      await _running;
      await _waitForUpdaterCalls();
      final int current = await _runUpdaterCall(_updater.currentPatchNumber(), checkTimeout) ?? 0;
      _safely(() => _tagPatch?.call(current));
      final StoreRelease release = _release();
      final String booted = _key(release, current);
      final String? previous = _settings.get<String?>(bootedKey);
      final String releasePrefix = _key(release, null);
      if (previous != null && previous != booted && previous.startsWith(releasePrefix)) {
        final int previousPatch = int.tryParse(previous.substring(releasePrefix.length)) ?? 0;
        _track(OtaPatchRunningEvent(patchNumber: current, previousPatchNumber: previousPatch));
      }
      await _settings.set(bootedKey, booted);
      final String? pending = _settings.get<String?>(pendingKey);
      if (pending != null && (pending == booted || !pending.startsWith(releasePrefix))) {
        await _settings.delete(pendingKey);
      }
    } catch (_) {
      // The updater keeps working without launch telemetry.
    }
  }

  /// Runs one check, and a download when a patch is available. A call while one runs joins it. A call within
  /// [cooldown] of the last one does nothing.
  Future<void> check({required String trigger}) {
    if (!_updater.isAvailable) return Future<void>.value();
    final Future<void>? launchRecording = _launchRecording;
    if (launchRecording != null && !_launchRecordingSettled) {
      return launchRecording.then((_) => check(trigger: trigger));
    }
    final Future<void>? running = _running;
    if (running != null) return running;
    if (_outstandingUpdaterCalls > 0) {
      return _waitForUpdaterCalls().then((_) => check(trigger: trigger));
    }
    final DateTime now = _now();
    final DateTime? last = _lastCheck;
    if (last != null && now.difference(last) < cooldown) return Future<void>.value();
    _lastCheck = now;
    _checkSettled = false;
    final Future<void> runningCheck = _check(trigger).whenComplete(() {
      _checkSettled = true;
      _clearRunningWhenIdle();
    });
    return _running = runningCheck;
  }

  /// The host showed [restart]. It is not shown again for this release and patch.
  Future<void> markAnnounced(PendingRestart restart) async {
    try {
      await _settings.set(announcedKey, restart.key);
    } catch (_) {
      return;
    }
    if (announcement.value == restart) announcement.value = null;
  }

  Future<void> _check(String trigger) async {
    int current = 0;
    bool downloading = false;
    String? pendingAtStart;
    try {
      try {
        pendingAtStart = _settings.get<String?>(pendingKey);
      } catch (_) {
        // Persistence must not block an OTA check.
      }
      current = await _runUpdaterCall(_updater.currentPatchNumber(), checkTimeout) ?? 0;
      _track(OtaCheckStartedEvent(trigger: trigger, patchNumber: current));
      final CodePushStatus status = await _runUpdaterCall(_updater.checkForUpdate(), checkTimeout);
      switch (status) {
        case CodePushStatus.outdated:
          _track(OtaUpdateAvailableEvent(patchNumber: current));
          downloading = true;
          await _runUpdaterCall(_updater.downloadUpdate(), downloadTimeout);
          downloading = false;
          final int next = await _runUpdaterCall(_updater.nextPatchNumber(), checkTimeout) ?? 0;
          if (next == current) return;
          _track(OtaDownloadDoneEvent(patchNumber: current, pendingPatchNumber: next));
          await _restartRequired(next);
        case CodePushStatus.restartRequired:
          final int next = await _runUpdaterCall(_updater.nextPatchNumber(), checkTimeout) ?? 0;
          if (next == current) {
            await _clearPendingRestart(pendingAtStart);
          } else {
            await _restartRequired(next);
          }
        case CodePushStatus.upToDate:
          await _clearPendingRestart(pendingAtStart);
          return;
        case CodePushStatus.unavailable:
          return;
      }
    } on TimeoutException {
      _fail(downloading ? OtaFailureReasonValue.downloadTimeout : OtaFailureReasonValue.checkTimeout, current);
    } on CodePushException catch (error) {
      _fail(switch (error.failure) {
        CodePushFailure.downloadFailed => OtaFailureReasonValue.downloadFailed,
        CodePushFailure.installFailed => OtaFailureReasonValue.installFailed,
        CodePushFailure.unknown => OtaFailureReasonValue.unknown,
      }, current);
    } catch (_) {
      _fail(downloading ? OtaFailureReasonValue.unknown : OtaFailureReasonValue.checkFailed, current);
    }
  }

  Future<void> _restartRequired(int patchNumber) async {
    final StoreRelease release = _release();
    final PendingRestart restart = PendingRestart(
      version: release.version,
      build: release.build,
      patchNumber: patchNumber,
    );
    final String? previousPending = _settings.get<String?>(pendingKey);
    await _settings.set(pendingKey, restart.key);
    if (previousPending != restart.key || _settings.get<String?>(announcedKey) != restart.key) {
      announcement.value = restart;
    }
  }

  Future<void> _clearPendingRestart(String? expectedPending) async {
    if (expectedPending == null) return;
    try {
      if (_settings.get<String?>(pendingKey) == expectedPending) await _settings.delete(pendingKey);
    } catch (_) {
      // A failed cleanup must not block the update check.
    }
    if (announcement.value?.key == expectedPending) announcement.value = null;
  }

  Future<T> _runUpdaterCall<T>(Future<T> call, Duration timeout) => _trackUpdaterCall(call).timeout(timeout);

  Future<T> _trackUpdaterCall<T>(Future<T> call) {
    if (_outstandingUpdaterCalls == 0) _updaterCallsDrained = Completer<void>();
    _outstandingUpdaterCalls++;
    return call.whenComplete(() {
      _outstandingUpdaterCalls--;
      if (_outstandingUpdaterCalls == 0) {
        _updaterCallsDrained?.complete();
        _updaterCallsDrained = null;
      }
      _clearRunningWhenIdle();
    });
  }

  Future<void> _waitForUpdaterCalls() =>
      _outstandingUpdaterCalls == 0 ? Future<void>.value() : _updaterCallsDrained!.future;

  void _clearRunningWhenIdle() {
    if (_checkSettled && _outstandingUpdaterCalls == 0) _running = null;
  }

  void _fail(OtaFailureReasonValue reason, int patchNumber) =>
      _track(OtaDownloadFailedEvent(reason: reason, patchNumber: patchNumber));

  String _key(StoreRelease release, int? patchNumber) => '${release.version}+${release.build}#${patchNumber ?? ''}';

  void _track(AnalyticsEvent event) => _safely(() => unawaited(_analytics.track(event).catchError((Object _) {})));

  void _safely(void Function() action) {
    try {
      action();
    } catch (_) {
      // Telemetry never changes what the updater does.
    }
  }
}
