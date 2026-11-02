import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/updates/code_push_updater.dart';
import 'package:Prism/core/updates/ota_update_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';
import 'fake_code_push_updater.dart';

class _RecordingAnalytics implements AppAnalytics {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  bool throwSync = false;
  bool failAsync = false;

  @override
  Future<void> track(AnalyticsEvent event) {
    if (throwSync) throw StateError('telemetry down');
    if (failAsync) return Future<void>.error(StateError('telemetry down'));
    events.add(event);
    return Future<void>.value();
  }

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({required String name, String? value}) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? parameters,
  }) async {}

  @override
  Future<void> flush() async {}
}

void main() {
  late SettingsLocalDataSource settings;
  late _RecordingAnalytics analytics;
  late DateTime now;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    analytics = _RecordingAnalytics();
    now = DateTime(2026, 10, 28);
  });

  OtaUpdateController controller(
    FakeCodePushUpdater updater, {
    StoreRelease release = (version: '3.14.0', build: '353'),
    void Function(int patchNumber)? tagPatch,
    Duration checkTimeout = const Duration(seconds: 30),
    Duration downloadTimeout = const Duration(minutes: 5),
  }) {
    return OtaUpdateController(
      updater: updater,
      settings: settings,
      analytics: analytics,
      release: () => release,
      tagPatch: tagPatch,
      now: () => now,
      checkTimeout: checkTimeout,
      downloadTimeout: downloadTimeout,
    );
  }

  List<AnalyticsEvent> eventsNamed(String name) =>
      analytics.events.where((AnalyticsEvent event) => event.eventName == name).toList();

  test('a launch check joins a resume check that is already running', () async {
    final Completer<void> gate = Completer<void>();
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..checkGate = gate;
    final OtaUpdateController c = controller(updater);

    final Future<void> launch = c.check(trigger: 'launch');
    final Future<void> resume = c.check(trigger: 'resume');
    gate.complete();
    await Future.wait(<Future<void>>[launch, resume]);

    expect(updater.checkCalls, 1);
    final List<AnalyticsEvent> started = eventsNamed('ota_check_started');
    expect(started, hasLength(1));
    expect(started.single.toWireParameters()['trigger'], 'launch');
  });

  test('a check within 15 minutes of the last one does nothing', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater();
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');
    expect(updater.checkCalls, 1);

    now = now.add(const Duration(minutes: 14));
    await c.check(trigger: 'resume');
    expect(updater.checkCalls, 1);

    now = now.add(const Duration(minutes: 1));
    await c.check(trigger: 'resume');
    expect(updater.checkCalls, 2);
  });

  test('an offline check fails quietly with check_failed', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..checkError = const SocketException('offline');
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');

    final List<AnalyticsEvent> failed = eventsNamed('ota_download_failed');
    expect(failed, hasLength(1));
    expect(failed.single.toWireParameters(), <String, Object?>{'reason': 'check_failed', 'patch_number': 0});
  });

  test('a check that never returns times out with check_timeout', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..checkGate = Completer<void>();
    final OtaUpdateController c = controller(updater, checkTimeout: const Duration(milliseconds: 50));

    await c.check(trigger: 'launch');

    final List<AnalyticsEvent> failed = eventsNamed('ota_download_failed');
    expect(failed, hasLength(1));
    expect(failed.single.toWireParameters()['reason'], 'check_timeout');
  });

  test('a timed out check remains a barrier until the SDK call settles', () async {
    final Completer<void> gate = Completer<void>();
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..checkGate = gate;
    final OtaUpdateController c = controller(updater, checkTimeout: const Duration(milliseconds: 20));

    await c.check(trigger: 'launch');
    now = now.add(const Duration(minutes: 16));
    await c.check(trigger: 'resume');

    expect(updater.checkCalls, 1);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
    await c.check(trigger: 'resume');

    expect(updater.checkCalls, 2);
  });

  test('current patch reads are bounded by the check timeout and held as an SDK barrier', () async {
    final Completer<void> gate = Completer<void>();
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..currentGate = gate;
    final OtaUpdateController c = controller(updater, checkTimeout: const Duration(milliseconds: 20));

    await c.check(trigger: 'launch');
    now = now.add(const Duration(minutes: 16));
    await c.check(trigger: 'resume');

    expect(updater.currentCalls, 1);
    final List<AnalyticsEvent> failed = eventsNamed('ota_download_failed');
    expect(failed.single.toWireParameters()['reason'], 'check_timeout');

    gate.complete();
    await Future<void>.delayed(Duration.zero);
    await c.check(trigger: 'resume');
    expect(updater.currentCalls, 2);
  });

  test('next patch reads are bounded and classified as a check timeout', () async {
    final Completer<void> gate = Completer<void>();
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.outdated
      ..nextAfterDownload = 1
      ..nextGate = gate;
    final OtaUpdateController c = controller(updater, checkTimeout: const Duration(milliseconds: 20));

    await c.check(trigger: 'launch');

    expect(updater.nextCalls, 1);
    expect(eventsNamed('ota_download_failed').single.toWireParameters()['reason'], 'check_timeout');

    gate.complete();
  });

  test('a failed download reports download_failed', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.outdated
      ..downloadError = const CodePushException(CodePushFailure.downloadFailed);
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');

    final List<AnalyticsEvent> failed = eventsNamed('ota_download_failed');
    expect(failed, hasLength(1));
    expect(failed.single.toWireParameters()['reason'], 'download_failed');
  });

  test('a failed install reports install_failed', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.outdated
      ..downloadError = const CodePushException(CodePushFailure.installFailed);
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');

    final List<AnalyticsEvent> failed = eventsNamed('ota_download_failed');
    expect(failed, hasLength(1));
    expect(failed.single.toWireParameters()['reason'], 'install_failed');
  });

  test('a download that never returns times out with download_timeout', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.outdated
      ..downloadGate = Completer<void>();
    final OtaUpdateController c = controller(updater, downloadTimeout: const Duration(milliseconds: 50));

    await c.check(trigger: 'launch');

    final List<AnalyticsEvent> failed = eventsNamed('ota_download_failed');
    expect(failed, hasLength(1));
    expect(failed.single.toWireParameters()['reason'], 'download_timeout');
  });

  test('a restartRequired check does not download again or report a finished download', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.restartRequired
      ..current = null
      ..next = 1;
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');

    expect(updater.downloadCalls, 0);
    expect(eventsNamed('ota_download_done'), isEmpty);
  });

  test('a downloaded patch reports each step in order', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.outdated
      ..current = null
      ..nextAfterDownload = 1;
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');

    expect(analytics.events.map((AnalyticsEvent e) => e.eventName), <String>[
      'ota_check_started',
      'ota_update_available',
      'ota_download_done',
    ]);
    expect(analytics.events[0].toWireParameters(), <String, Object?>{'trigger': 'launch', 'patch_number': 0});
    expect(analytics.events[1].toWireParameters(), <String, Object?>{'patch_number': 0});
    expect(analytics.events[2].toWireParameters(), <String, Object?>{'patch_number': 0, 'pending_patch_number': 1});
  });

  test('a debug or non-Shorebird build skips checks and launch telemetry', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..isAvailable = false;
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');
    await c.recordLaunch();

    expect(updater.checkCalls, 0);
    expect(analytics.events, isEmpty);
    expect(settings.get<String?>(OtaUpdateController.bootedKey), isNull);
  });

  test('a telemetry throw does not stop the download', () async {
    analytics.throwSync = true;
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.outdated
      ..current = null
      ..nextAfterDownload = 1;
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');

    expect(updater.downloadCalls, 1);
  });

  test('an async telemetry failure does not stop the download', () async {
    analytics.failAsync = true;
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..status = CodePushStatus.outdated
      ..current = null
      ..nextAfterDownload = 1;
    final OtaUpdateController c = controller(updater);

    await c.check(trigger: 'launch');

    expect(updater.downloadCalls, 1);
  });

  test('a failing patch tag does not stop launch recording', () async {
    final FakeCodePushUpdater updater = FakeCodePushUpdater();
    final OtaUpdateController c = controller(updater, tagPatch: (int patchNumber) => throw StateError('sentry down'));

    await c.recordLaunch();

    expect(settings.get<String?>(OtaUpdateController.bootedKey), '3.14.0+353#0');
  });

  test('recordLaunch tags the running patch number', () async {
    final List<int> tagged = <int>[];
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..current = 1;
    final OtaUpdateController c = controller(updater, tagPatch: tagged.add);

    await c.recordLaunch();

    expect(tagged, <int>[1]);
  });

  test('recordLaunch reports a patch that runs for the first time, once', () async {
    await settings.set(OtaUpdateController.bootedKey, '3.14.0+353#0');
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..current = 1;
    final OtaUpdateController c = controller(updater);

    await c.recordLaunch();

    final List<AnalyticsEvent> running = eventsNamed('ota_patch_running');
    expect(running, hasLength(1));
    expect(running.single.toWireParameters(), <String, Object?>{'patch_number': 1, 'previous_patch_number': 0});
    expect(settings.get<String?>(OtaUpdateController.bootedKey), '3.14.0+353#1');

    await c.recordLaunch();

    expect(eventsNamed('ota_patch_running'), hasLength(1));
  });

  test('concurrent recordLaunch calls read and persist launch state once', () async {
    await settings.set(OtaUpdateController.bootedKey, '3.14.0+353#0');
    final Completer<void> gate = Completer<void>();
    final FakeCodePushUpdater updater = FakeCodePushUpdater()
      ..current = 1
      ..currentGate = gate;
    final OtaUpdateController c = controller(updater);

    final Future<void> first = c.recordLaunch();
    final Future<void> second = c.recordLaunch();
    gate.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(updater.currentCalls, 1);
    expect(eventsNamed('ota_patch_running'), hasLength(1));
  });

  test('a check requested during launch recording runs after the launch read settles', () async {
    final Completer<void> gate = Completer<void>();
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..currentGate = gate;
    final OtaUpdateController c = controller(updater);

    final Future<void> launchRecording = c.recordLaunch();
    final Future<void> check = c.check(trigger: 'launch');
    gate.complete();
    await Future.wait(<Future<void>>[launchRecording, check]);

    expect(updater.currentCalls, 2);
    expect(updater.checkCalls, 1);
  });

  test('recordLaunch reports nothing when the last boot was another release', () async {
    await settings.set(OtaUpdateController.bootedKey, '3.13.0+352#4');
    final FakeCodePushUpdater updater = FakeCodePushUpdater()..current = 1;
    final OtaUpdateController c = controller(updater);

    await c.recordLaunch();

    expect(eventsNamed('ota_patch_running'), isEmpty);
  });

  test('a new store release treats its patch as a new transition', () async {
    const StoreRelease newRelease = (version: '3.14.1', build: '354');
    final OtaUpdateController c = controller(FakeCodePushUpdater()..current = 1, release: newRelease);

    await c.recordLaunch();

    expect(settings.get<String?>(OtaUpdateController.bootedKey), '3.14.1+354#1');
  });
}
