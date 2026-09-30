import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAutoRotateRepository implements AutoRotateRepository {
  _FakeAutoRotateRepository({this.config = const AutoRotateConfig(), this.running = false});

  AutoRotateConfig config;
  bool running;
  bool startResult = true;
  final List<(AutoRotateConfig, List<String>)> starts = <(AutoRotateConfig, List<String>)>[];
  int stops = 0;
  int rotateNows = 0;

  @override
  Future<AutoRotateConfig> loadConfig() async => config;

  @override
  Future<void> saveConfig(AutoRotateConfig config) async => this.config = config;

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    starts.add((config, imageUrls));
    running = startResult;
    return startResult;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  Future<AutoRotateStatus> status() async => AutoRotateStatus(isRunning: running, nextRunEpochMs: running ? 1000 : 0);

  @override
  Future<bool> rotateNow() async {
    rotateNows++;
    return true;
  }
}

void main() {
  const urls = <String>['https://a.test/1.jpg', 'https://a.test/2.jpg', 'https://a.test/3.jpg'];

  late _FakeAutoRotateRepository repo;

  setUp(() => repo = _FakeAutoRotateRepository());

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
    build: build,
    act: (bloc) async {
      bloc.add(const AutoRotateEvent.started(favouriteUrls: urls, isPro: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.toggled(true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AutoRotateEvent.favouritesChanged(<String>['https://a.test/1.jpg']));
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
}
