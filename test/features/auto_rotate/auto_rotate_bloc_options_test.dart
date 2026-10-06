import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeRepository implements AutoRotateRepository {
  AutoRotateConfig config = const AutoRotateConfig(enabled: true);
  AutoRotateStatus statusValue = const AutoRotateStatus();
  List<String>? applied;
  List<String> downloads = <String>[];
  bool tipAvailable = true;
  int? startCached;
  final List<(AutoRotateConfig, List<String>)> starts = <(AutoRotateConfig, List<String>)>[];
  int stops = 0;

  @override
  Future<AutoRotateConfig> loadConfig() async => config;

  @override
  Future<void> saveConfig(AutoRotateConfig config) async => this.config = config;

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    starts.add((config, imageUrls));
    applied = imageUrls;
    statusValue = AutoRotateStatus(
      isRunning: true,
      nextRunEpochMs: 1,
      cachedCount: startCached ?? imageUrls.length,
      totalCount: imageUrls.length,
    );
    return true;
  }

  @override
  Future<bool> stop() async {
    stops++;
    applied = null;
    statusValue = const AutoRotateStatus();
    return true;
  }

  @override
  Future<AutoRotateStatus> status() async => statusValue;

  @override
  Future<bool> rotateNow() async => true;

  @override
  Future<List<String>?> loadAppliedSources() async => applied;

  @override
  Future<List<String>> listDownloads() async => downloads;

  @override
  Future<bool> consumeBatteryTip() async {
    final bool available = tipAvailable;
    tipAvailable = false;
    return available;
  }
}

List<String> _urls(int count) => List<String>.generate(count, (i) => 'https://example.com/$i.jpg');

Future<void> _settle([int milliseconds = 120]) => Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  late _FakeRepository repository;
  late AutoRotateBloc bloc;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    repository = _FakeRepository();
    bloc = AutoRotateBloc(repository)..favouritesDebounce = const Duration(milliseconds: 40);
  });

  tearDown(() async {
    await bloc.close();
    AnalyticsRuntime.reset();
  });

  Future<void> openAsPro(List<String> urls) async {
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'u1'));
    bloc.add(AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
    await _settle();
  }

  group('favourite changes', () {
    test('restart once after a burst of changes', () async {
      await openAsPro(_urls(2));
      expect(repository.starts, hasLength(1));

      bloc.add(AutoRotateEvent.favouritesChanged(_urls(3)));
      bloc.add(AutoRotateEvent.favouritesChanged(_urls(4)));
      bloc.add(AutoRotateEvent.favouritesChanged(_urls(5)));
      await _settle(10);

      expect(repository.starts, hasLength(1));
      expect(bloc.state.favouriteCount, 5);

      await _settle();
      expect(repository.starts, hasLength(2));
      expect(repository.starts.last.$2, _urls(5));
    });

    test('do not restart when the list is the same', () async {
      await openAsPro(_urls(3));
      expect(repository.starts, hasLength(1));

      bloc.add(AutoRotateEvent.favouritesChanged(_urls(3)));
      await _settle();

      expect(repository.starts, hasLength(1));
    });

    test('do not restart when a burst ends on the applied list', () async {
      await openAsPro(_urls(3));

      bloc.add(AutoRotateEvent.favouritesChanged(_urls(4)));
      bloc.add(AutoRotateEvent.favouritesChanged(_urls(3)));
      await _settle();

      expect(repository.starts, hasLength(1));
    });

    test('do not restart on launch when the running playlist already matches', () async {
      repository
        ..applied = _urls(3)
        ..statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);

      await openAsPro(_urls(3));
      bloc.add(AutoRotateEvent.favouritesChanged(_urls(3)));
      await _settle();

      expect(repository.starts, isEmpty);
      expect(repository.stops, 0);
    });

    test('use the first 100 favourites and say so', () async {
      await openAsPro(_urls(120));

      expect(bloc.state.favouriteCount, 100);
      expect(bloc.state.sourcesCapped, isTrue);
      expect(repository.starts.single.$2, hasLength(100));
    });
  });

  group('settings', () {
    test('a no-op setting change does not restart', () async {
      await openAsPro(_urls(3));

      bloc.add(AutoRotateEvent.intervalChanged(repository.config.intervalMinutes));
      bloc.add(AutoRotateEvent.shuffleChanged(repository.config.shuffle));
      await _settle();

      expect(repository.starts, hasLength(1));
    });

    test('charging only restarts rotation and persists', () async {
      await openAsPro(_urls(3));

      bloc.add(const AutoRotateEvent.chargingOnlyChanged(true));
      await _settle();

      expect(repository.starts, hasLength(2));
      expect(repository.starts.last.$1.chargingOnly, isTrue);
      expect(repository.config.chargingOnly, isTrue);
    });

    test('switching to downloads starts rotation with the downloaded files', () async {
      repository.downloads = <String>['/d/1.jpg', '/d/2.jpg', '/d/3.jpg'];
      await openAsPro(_urls(3));

      bloc.add(const AutoRotateEvent.sourceChanged(AutoRotateSource.downloads));
      await _settle();

      expect(repository.starts.last.$1.source, AutoRotateSource.downloads);
      expect(repository.starts.last.$2, repository.downloads);
      expect(bloc.state.downloadCount, 3);
      expect(bloc.state.sourceCount, 3);
    });

    test('switching to a source with too few wallpapers stops rotation', () async {
      repository.downloads = <String>['/d/1.jpg'];
      await openAsPro(_urls(3));

      bloc.add(const AutoRotateEvent.sourceChanged(AutoRotateSource.downloads));
      await _settle();

      expect(repository.stops, 1);
      expect(bloc.state.config.enabled, isFalse);
      expect(bloc.state.config.source, AutoRotateSource.downloads);
    });
  });

  group('enabling', () {
    test('shows starting, then one battery tip', () async {
      repository.config = const AutoRotateConfig();
      await openAsPro(_urls(3));
      final List<AutoRotateState> states = <AutoRotateState>[];
      final StreamSubscription<AutoRotateState> subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      bloc.add(const AutoRotateEvent.toggled(true));
      await _settle();

      expect(states.any((state) => state.starting && state.config.enabled == false), isTrue);
      expect(bloc.state.starting, isFalse);
      expect(bloc.state.showBatteryTip, isTrue);

      bloc.add(const AutoRotateEvent.batteryTipDismissed());
      bloc.add(const AutoRotateEvent.toggled(false));
      await _settle();
      bloc.add(const AutoRotateEvent.toggled(true));
      await _settle();

      expect(bloc.state.showBatteryTip, isFalse);
    });

    test('keeps polling progress until every wallpaper is cached', () async {
      bloc.statusPollInterval = const Duration(milliseconds: 20);
      repository.startCached = 1;
      await openAsPro(_urls(4));
      expect(bloc.state.status.cachedCount, 1);

      repository.statusValue = const AutoRotateStatus(
        isRunning: true,
        nextRunEpochMs: 1,
        cachedCount: 3,
        totalCount: 4,
      );
      await _settle(60);
      expect(bloc.state.status.cachedCount, 3);

      repository.statusValue = const AutoRotateStatus(
        isRunning: true,
        nextRunEpochMs: 1,
        cachedCount: 4,
        totalCount: 4,
      );
      await _settle(60);
      expect(bloc.state.status.cachedCount, 4);
    });
  });

  group('non-Pro', () {
    test('resume does not stop rotation again when it is already off', () async {
      repository.config = const AutoRotateConfig();

      for (var i = 0; i < 3; i++) {
        bloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: 'u1'));
      }
      await _settle();

      expect(repository.stops, 0);
    });

    test('stop a leftover rotation once', () async {
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);

      for (var i = 0; i < 3; i++) {
        bloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: 'u1'));
      }
      await _settle();

      expect(repository.stops, 1);
    });
  });
}
