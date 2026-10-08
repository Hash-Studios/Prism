import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeRepository implements AutoRotateRepository {
  AutoRotateConfig config = const AutoRotateConfig();
  AutoRotateStatus statusValue = const AutoRotateStatus();
  List<String>? applied;
  Map<AutoRotateSource, List<String>?> remote = <AutoRotateSource, List<String>?>{};
  Map<String, List<String>?> categories = <String, List<String>?>{};
  Set<WallpaperTarget> targets = WallpaperTarget.values.toSet();
  bool rotateNowResult = true;
  int remoteLoads = 0;
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
      cachedCount: imageUrls.length,
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
  Future<bool> rotateNow() async => rotateNowResult;

  @override
  Future<List<String>?> loadAppliedSources() async => applied;

  @override
  Future<List<String>> listDownloads() async => const <String>[];

  @override
  Future<List<String>?> loadRemoteUrls(AutoRotateSource source, {String? category}) async {
    remoteLoads++;
    if (source == AutoRotateSource.category) return categories[category];
    return remote[source];
  }

  @override
  Future<Set<WallpaperTarget>> supportedTargets() async => targets;

  @override
  Future<bool> consumeBatteryTip() async => false;
}

List<String> _urls(String prefix, int count) =>
    List<String>.generate(count, (i) => 'https://example.com/$prefix$i.jpg', growable: false);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  late _FakeRepository repository;
  late AutoRotateBloc bloc;
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    repository = _FakeRepository();
    bloc = AutoRotateBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
    AnalyticsRuntime.reset();
  });

  Future<void> openAsPro({List<String> favourites = const <String>[]}) async {
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'u1'));
    bloc.add(AutoRotateEvent.started(favouriteUrls: favourites, isPro: true));
    await _settle();
  }

  group('category source', () {
    test('picking a category loads its walls, saves the choice and starts the rotation with them', () async {
      repository.categories['Space'] = _urls('space', 5);
      repository.config = const AutoRotateConfig(enabled: true);
      await openAsPro(favourites: _urls('fav', 3));
      expect(repository.starts.single.$2, _urls('fav', 3));

      bloc.add(const AutoRotateEvent.categoryChanged('Space'));
      await _settle();

      expect(repository.config.source, AutoRotateSource.category);
      expect(repository.config.categoryName, 'Space');
      expect(repository.starts.last.$1.source, AutoRotateSource.category);
      expect(repository.starts.last.$2, _urls('space', 5));
      expect(bloc.state.remoteCount, 5);
      expect(bloc.state.sourceCount, 5);
      expect(bloc.state.loadingSource, isFalse);
    });

    test('the first enable reports the source and the category', () async {
      repository.categories['Nature'] = _urls('nature', 4);
      repository.config = const AutoRotateConfig(source: AutoRotateSource.category);
      await openAsPro();

      bloc.add(const AutoRotateEvent.toggled(true));
      await _settle();

      final AutoRotateEnabledEvent event = analytics.events.whereType<AutoRotateEnabledEvent>().single;
      expect(event.source, 'category');
      expect(event.category, 'Nature');
      expect(event.wallpaperCount, 4);
    });

    test('another source reports no category', () async {
      await openAsPro(favourites: _urls('fav', 3));

      bloc.add(const AutoRotateEvent.toggled(true));
      await _settle();

      final AutoRotateEnabledEvent event = analytics.events.whereType<AutoRotateEnabledEvent>().single;
      expect(event.source, 'favourites');
      expect(event.category, isNull);
    });

    test('reopening the screen with the same walls does not restart the rotation', () async {
      repository.categories['Nature'] = _urls('nature', 4);
      repository.config = const AutoRotateConfig(source: AutoRotateSource.category);
      await openAsPro();
      bloc.add(const AutoRotateEvent.toggled(true));
      await _settle();
      expect(repository.starts, hasLength(1));

      bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
      await _settle();

      expect(repository.starts, hasLength(1));
    });

    test('reopening the screen with a new wall restarts the rotation once', () async {
      repository.categories['Nature'] = _urls('nature', 4);
      repository.config = const AutoRotateConfig(source: AutoRotateSource.category);
      await openAsPro();
      bloc.add(const AutoRotateEvent.toggled(true));
      await _settle();

      repository.categories['Nature'] = _urls('nature', 5);
      bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
      await _settle();

      expect(repository.starts, hasLength(2));
      expect(repository.starts.last.$2, _urls('nature', 5));
    });

    test('a category that cannot load keeps the old source and its rotation', () async {
      repository.config = const AutoRotateConfig(enabled: true);
      await openAsPro(favourites: _urls('fav', 3));

      bloc.add(const AutoRotateEvent.categoryChanged('Space'));
      await _settle();

      expect(repository.config.source, AutoRotateSource.favourites);
      expect(repository.stops, 0);
      expect(repository.starts, hasLength(1));
      expect(bloc.state.sourceLoadFailed, isTrue);
      expect(bloc.state.loadingSource, isFalse);
      expect(bloc.state.status.isRunning, isTrue);
    });

    test('opening the screen offline leaves a running category rotation alone', () async {
      repository.config = const AutoRotateConfig(enabled: true, source: AutoRotateSource.category);
      repository.applied = _urls('nature', 4);
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);

      await openAsPro();

      expect(repository.stops, 0);
      expect(repository.starts, isEmpty);
      expect(bloc.state.config.enabled, isTrue);
      expect(bloc.state.status.isRunning, isTrue);
      expect(bloc.state.sourceLoadFailed, isTrue);
    });

    test('Try again loads the walls and turns the rotation on', () async {
      repository.config = const AutoRotateConfig(source: AutoRotateSource.category);
      await openAsPro();
      expect(bloc.state.sourceLoadFailed, isTrue);

      repository.categories['Nature'] = _urls('nature', 3);
      bloc.add(const AutoRotateEvent.toggled(true));
      await _settle();

      expect(bloc.state.sourceLoadFailed, isFalse);
      expect(bloc.state.config.enabled, isTrue);
      expect(repository.starts.single.$2, _urls('nature', 3));
    });
  });

  group('other sources', () {
    test('Wall of the Day and history start with their own lists', () async {
      repository.remote[AutoRotateSource.wallOfTheDay] = _urls('wotd', 3);
      repository.remote[AutoRotateSource.history] = _urls('hist', 2);
      repository.config = const AutoRotateConfig(enabled: true);
      await openAsPro(favourites: _urls('fav', 3));

      bloc.add(const AutoRotateEvent.sourceChanged(AutoRotateSource.wallOfTheDay));
      await _settle();
      expect(repository.starts.last.$2, _urls('wotd', 3));

      bloc.add(const AutoRotateEvent.sourceChanged(AutoRotateSource.history));
      await _settle();
      expect(repository.starts.last.$2, _urls('hist', 2));
      expect(bloc.state.sourceCount, 2);
    });

    test('drops urls that are not https and duplicates from a remote list', () async {
      repository.remote[AutoRotateSource.wallOfTheDay] = <String>[
        'https://example.com/a.jpg',
        'https://example.com/a.jpg',
        'http://example.com/b.jpg',
        'https://example.com/c.jpg',
      ];
      repository.config = const AutoRotateConfig(source: AutoRotateSource.wallOfTheDay);
      await openAsPro();

      expect(bloc.state.remoteCount, 2);
    });

    test('does not load a remote list for a user who is not Pro', () async {
      repository.config = const AutoRotateConfig(source: AutoRotateSource.category);
      bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: false));
      await _settle();

      expect(repository.remoteLoads, 0);
    });
  });

  group('intervals', () {
    test('accepts every new interval and restarts with it', () async {
      repository.config = const AutoRotateConfig(enabled: true);
      await openAsPro(favourites: _urls('fav', 3));

      for (final int minutes in <int>[15, 30, 180, 4320, 10080]) {
        bloc.add(AutoRotateEvent.intervalChanged(minutes));
        await _settle();
        expect(repository.starts.last.$1.intervalMinutes, minutes);
      }
    });
  });

  group('targets', () {
    test('keeps only the targets the device supports in the state', () async {
      repository.targets = <WallpaperTarget>{WallpaperTarget.home};

      await openAsPro(favourites: _urls('fav', 3));

      expect(bloc.state.supportedTargets, <WallpaperTarget>{WallpaperTarget.home});
    });
  });

  group('Pro lapse', () {
    test('turns rotation off and flags the lapse when the user is no longer Pro at app start', () async {
      repository.config = const AutoRotateConfig(enabled: true);
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);

      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: 'u1'));
      await _settle();

      expect(repository.stops, 1);
      expect(repository.config.enabled, isFalse);
      expect(bloc.state.proLapsed, isTrue);

      bloc.add(const AutoRotateEvent.proLapseAcknowledged());
      await _settle();
      expect(bloc.state.proLapsed, isFalse);
    });

    test('says nothing when rotation was already off', () async {
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: 'u1'));
      await _settle();

      expect(bloc.state.proLapsed, isFalse);
    });

    test('says nothing when the user signs out', () async {
      repository.config = const AutoRotateConfig(enabled: true);
      repository.statusValue = const AutoRotateStatus(isRunning: true, nextRunEpochMs: 1);
      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'u1'));
      await _settle();

      bloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: ''));
      await _settle();

      expect(repository.stops, 1);
      expect(bloc.state.proLapsed, isFalse);
    });
  });

  group('rotate now', () {
    test('reports the result', () async {
      repository.config = const AutoRotateConfig(enabled: true);
      await openAsPro(favourites: _urls('fav', 3));

      bloc.add(const AutoRotateEvent.rotateNowPressed());
      await _settle();
      repository.rotateNowResult = false;
      bloc.add(const AutoRotateEvent.rotateNowPressed());
      await _settle();

      expect(analytics.events.whereType<AutoRotateRunResultEvent>().map((event) => event.result), <BinaryResultValue>[
        BinaryResultValue.success,
        BinaryResultValue.failure,
      ]);
    });
  });
}
