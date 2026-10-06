import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeAutoRotateRepository implements AutoRotateRepository {
  _FakeAutoRotateRepository({this.config = const AutoRotateConfig(), this.running = false});

  AutoRotateConfig config;
  bool running;
  bool startResult = true;
  bool stopResult = true;
  bool rotateNowResult = true;
  Object? startError;
  Object? stopError;
  Object? statusError;
  String? statusLastError;
  Object? rotateNowError;
  Completer<void>? startGate;
  Completer<void>? startEntered;
  Completer<void>? stopGate;
  int _activeMutations = 0;
  int maxActiveMutations = 0;
  final List<(AutoRotateConfig, List<String>)> starts = <(AutoRotateConfig, List<String>)>[];
  int stops = 0;
  int rotateNows = 0;
  List<String>? applied;

  @override
  Future<AutoRotateConfig> loadConfig() async => config;

  @override
  Future<void> saveConfig(AutoRotateConfig config) async => this.config = config;

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    starts.add((config, imageUrls));
    _activeMutations++;
    if (_activeMutations > maxActiveMutations) maxActiveMutations = _activeMutations;
    if (startEntered case final Completer<void> entered when !entered.isCompleted) entered.complete();
    try {
      await startGate?.future;
      if (startError case final Object error) throw error;
      running = startResult;
      if (startResult) applied = imageUrls;
      return startResult;
    } finally {
      _activeMutations--;
    }
  }

  @override
  Future<bool> stop() async {
    stops++;
    _activeMutations++;
    if (_activeMutations > maxActiveMutations) maxActiveMutations = _activeMutations;
    try {
      await stopGate?.future;
      if (stopError case final Object error) throw error;
      running = !stopResult;
      return stopResult;
    } finally {
      _activeMutations--;
    }
  }

  @override
  Future<AutoRotateStatus> status() async {
    if (statusError case final Object error) throw error;
    return AutoRotateStatus(isRunning: running, nextRunEpochMs: running ? 1000 : 0, lastError: statusLastError);
  }

  @override
  Future<bool> rotateNow() async {
    rotateNows++;
    if (rotateNowError case final Object error) throw error;
    statusLastError = rotateNowResult ? null : 'Wallpaper apply failed';
    return rotateNowResult;
  }

  @override
  Future<List<String>?> loadAppliedSources() async => applied;

  @override
  Future<List<String>> listDownloads() async => const <String>[];

  @override
  Future<bool> consumeBatteryTip() async => false;
}

void main() {
  const urls = <String>['https://a.test/1.jpg', 'https://a.test/2.jpg', 'https://a.test/3.jpg'];

  late _FakeAutoRotateRepository repo;
  late FakeAppAnalytics recordingAnalytics;

  setUp(() {
    repo = _FakeAutoRotateRepository();
    recordingAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = recordingAnalytics;
  });
  tearDown(AnalyticsRuntime.reset);

  AutoRotateBloc build() => AutoRotateBloc(repo);

  blocTest<AutoRotateBloc, AutoRotateState>(
    'enabling starts rotation with the favourite urls and config',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
    },
    verify: (bloc) {
      expect(repo.starts, hasLength(1));
      expect(repo.starts.single.$1, const AutoRotateConfig(enabled: true));
      expect(repo.starts.single.$2, urls);
      expect(repo.config.enabled, isTrue);
      expect(bloc.state.status.isRunning, isTrue);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'changing the interval while enabled restarts with the new interval',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.intervalChanged(60));
    },
    verify: (bloc) {
      expect(repo.starts, hasLength(2));
      expect(repo.starts.last.$1.intervalMinutes, 60);
      expect(repo.config.intervalMinutes, 60);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'changing a setting while disabled saves without starting',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.targetChanged(WallpaperTarget.both));
    },
    verify: (bloc) {
      expect(repo.starts, isEmpty);
      expect(repo.config.target, WallpaperTarget.both);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'disabling stops rotation',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(false));
    },
    verify: (bloc) {
      expect(repo.stops, 1);
      expect(repo.config.enabled, isFalse);
      expect(bloc.state.status.isRunning, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'fewer than 2 favourites never starts',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>['https://a.test/1.jpg'], isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
    },
    verify: (bloc) {
      expect(repo.starts, isEmpty);
      expect(bloc.state.config.enabled, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'dropping below 2 favourites while enabled stops rotation',
    build: () => build()..favouritesDebounce = const Duration(milliseconds: 10),
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.favouritesChanged(<String>['https://a.test/1.jpg']));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    },
    verify: (bloc) {
      expect(repo.stops, 1);
      expect(bloc.state.config.enabled, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'non-Pro user with a running rotation gets it stopped',
    setUp: () => repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true),
    build: build,
    act: (bloc) => bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: false)),
    verify: (bloc) {
      expect(repo.stops, 1);
      expect(repo.starts, isEmpty);
      expect(repo.config.enabled, isFalse);
      expect(repo.running, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a failed start leaves rotation off and flags the error',
    setUp: () => repo = _FakeAutoRotateRepository()..startResult = false,
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
    },
    verify: (bloc) {
      expect(bloc.state.startFailed, isTrue);
      expect(bloc.state.config.enabled, isFalse);
      expect(repo.config.enabled, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'change now rotates only while enabled',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.rotateNowPressed());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.rotateNowPressed());
    },
    verify: (bloc) => expect(repo.rotateNows, 1),
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a repeated identical favourite list does not restart rotation',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.favouritesChanged(urls));
    },
    verify: (bloc) => expect(repo.starts, hasLength(1)),
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'repeating the enabled toggle and current setting does not restart rotation',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.intervalChanged(60));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.intervalChanged(60));
      bloc.add(const AutoRotateEvent.toggled(true));
    },
    verify: (bloc) => expect(repo.starts, hasLength(2)),
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'counts unique valid HTTPS URLs only',
    build: build,
    act: (bloc) => bloc.add(
      const AutoRotateEvent.started(
        favouriteUrls: <String>[
          'https://a.test/1.jpg',
          'https://a.test/1.jpg',
          'https://b.test/2.jpg',
          'https://',
          'https://?query=only',
          ' https://c.test/3.jpg',
          'http://d.test/4.jpg',
        ],
        isPro: true,
      ),
    ),
    expect: () => <AutoRotateState>[AutoRotateState.initial().copyWith(loaded: true, isPro: true, favouriteCount: 2)],
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a platform exception while starting leaves saved config disabled',
    setUp: () => repo.startError = PlatformException(code: 'start_failed'),
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
    },
    verify: (bloc) {
      expect(bloc.state.config.enabled, isFalse);
      expect(repo.config.enabled, isFalse);
      expect(bloc.state.startFailed, isTrue);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a platform exception while reading status disables saved rotation',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true))
          ..statusError = PlatformException(code: 'status_failed'),
    build: build,
    act: (bloc) => bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true)),
    verify: (bloc) {
      expect(repo.config.enabled, isFalse);
      expect(bloc.state.config.enabled, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'startup refreshes the playlist when rotation is already running',
    setUp: () => repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true),
    build: build,
    act: (bloc) => bloc.add(
      const AutoRotateEvent.started(
        favouriteUrls: <String>['https://a.test/new.jpg', 'https://b.test/new.jpg'],
        isPro: true,
      ),
    ),
    verify: (bloc) {
      expect(repo.starts, hasLength(1));
      expect(repo.starts.single.$2, <String>['https://a.test/new.jpg', 'https://b.test/new.jpg']);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'reopening an unchanged running playlist does not restart it twice',
    setUp: () => repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true),
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
    },
    verify: (bloc) => expect(repo.starts, hasLength(1)),
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'Pro startup loads rotation before favorite URLs arrive',
    setUp: () => repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true),
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.favouritesChanged(urls));
    },
    verify: (bloc) {
      expect(repo.starts, hasLength(1));
      expect(repo.starts.single.$2, urls);
      expect(repo.stops, 0);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a running schedule with a prior apply error survives favorite and session refreshes',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true)
          ..statusLastError = 'Wallpaper apply failed',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.favouritesChanged(urls));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account'));
      bloc.add(const AutoRotateEvent.favouritesChanged(urls));
    },
    verify: (bloc) {
      expect(repo.stops, 0);
      expect(repo.config.enabled, isTrue);
      expect(bloc.state.status.isRunning, isTrue);
      expect(bloc.state.status.lastError, 'Wallpaper apply failed');
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a successful manual retry clears the persisted apply error',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true)
          ..statusLastError = 'Wallpaper apply failed',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.rotateNowPressed());
    },
    verify: (bloc) {
      expect(repo.config.enabled, isTrue);
      expect(bloc.state.status.isRunning, isTrue);
      expect(bloc.state.status.lastError, isNull);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'the first empty favorites result stops saved rotation',
    setUp: () => repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true),
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.favouritesChanged(<String>[]));
    },
    verify: (bloc) {
      expect(repo.starts, isEmpty);
      expect(repo.stops, 1);
      expect(repo.config.enabled, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'an unknown status does not re-download, and a successful stop confirms off',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true)
          ..statusError = PlatformException(code: 'status-unavailable'),
    build: build,
    act: (bloc) => bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true)),
    verify: (bloc) {
      expect(repo.starts, isEmpty);
      expect(repo.stops, 1);
      expect(repo.config.enabled, isFalse);
      expect(bloc.state.status.isRunning, isFalse);
      expect(bloc.state.status.lastError, isNull);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a saved-off rotation with a running native worker is stopped on startup',
    setUp: () => repo = _FakeAutoRotateRepository(running: true),
    build: build,
    act: (bloc) => bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true)),
    verify: (bloc) {
      expect(repo.starts, isEmpty);
      expect(repo.stops, 1);
      expect(repo.config.enabled, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a stale Pro startup cannot undo an entitlement revocation',
    setUp: () => repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true),
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: 'account'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
    },
    verify: (bloc) {
      expect(repo.starts, isEmpty);
      expect(repo.config.enabled, isFalse);
      expect(bloc.state.config.enabled, isFalse);
      expect(bloc.state.isPro, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a platform exception while stopping still clears saved config and keeps observed running status',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true)
          ..stopError = PlatformException(code: 'stop_failed'),
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(false));
    },
    verify: (bloc) {
      expect(repo.config.enabled, isFalse);
      expect(bloc.state.config.enabled, isFalse);
      expect(bloc.state.status.isRunning, isTrue);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a failed stop keeps running status and retries when disabled again',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true)
          ..stopResult = false,
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(false));
      await Future<void>.delayed(Duration.zero);
      repo.stopResult = true;
      bloc.add(const AutoRotateEvent.toggled(false));
    },
    verify: (bloc) {
      expect(repo.stops, 2);
      expect(bloc.state.status.isRunning, isFalse);
      expect(recordingAnalytics.events.whereType<AutoRotateDisabledEvent>(), hasLength(1));
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a platform exception while rotating now keeps a running schedule enabled',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true)
          ..rotateNowError = PlatformException(code: 'rotate_failed'),
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.rotateNowPressed());
    },
    verify: (bloc) {
      expect(repo.config.enabled, isTrue);
      expect(bloc.state.config.enabled, isTrue);
      expect(bloc.state.status.isRunning, isTrue);
      expect(bloc.state.status.lastError, isNotNull);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a failed manual apply keeps a still-running schedule enabled',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true), running: true)
          ..rotateNowResult = false,
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.rotateNowPressed());
    },
    verify: (bloc) {
      expect(repo.config.enabled, isTrue);
      expect(bloc.state.config.enabled, isTrue);
      expect(bloc.state.status.isRunning, isTrue);
      expect(bloc.state.status.lastError, isNotNull);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'a failed manual rotation disables a schedule only when status confirms it stopped',
    setUp: () =>
        repo = _FakeAutoRotateRepository(config: const AutoRotateConfig(enabled: true))..rotateNowResult = false,
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      repo.running = false;
      bloc.add(const AutoRotateEvent.rotateNowPressed());
    },
    verify: (bloc) {
      expect(repo.config.enabled, isFalse);
      expect(bloc.state.config.enabled, isFalse);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'events from different types do not overlap platform mutations',
    build: () => AutoRotateBloc(
      repo
        ..startGate = Completer<void>()
        ..startEntered = Completer<void>()
        ..stopGate = Completer<void>(),
    ),
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await repo.startEntered!.future;
      bloc.add(const AutoRotateEvent.toggled(false));
      await Future<void>.delayed(Duration.zero);
      repo.startGate!.complete();
      repo.stopGate!.complete();
    },
    verify: (bloc) {
      expect(repo.starts, hasLength(1));
      expect(repo.maxActiveMutations, 1);
    },
  );

  blocTest<AutoRotateBloc, AutoRotateState>(
    'enable and disable analytics each fire once per real transition',
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.favouritesChanged(urls));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(false));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(false));
    },
    verify: (bloc) {
      expect(recordingAnalytics.events.whereType<AutoRotateEnabledEvent>(), hasLength(1));
      expect(recordingAnalytics.events.whereType<AutoRotateDisabledEvent>(), hasLength(1));
    },
  );
}
