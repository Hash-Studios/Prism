import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

const List<String> _folderUrls = <String>['https://example.com/one.jpg', 'https://example.com/two.jpg'];
const List<String> _favouriteUrls = <String>['https://favorites.example/one.jpg', 'https://favorites.example/two.jpg'];
const List<String> _resolvedFavouriteUrls = <String>['/app/files/one.jpg', '/app/files/two.jpg'];

class _Repository implements AutoRotateRepository {
  AutoRotateConfig config = const AutoRotateConfig(
    enabled: true,
    source: AutoRotateSource.folder,
    folderId: 'folder-a',
    folderName: 'Private folder',
  );
  final List<String> loadedOwners = <String>[];
  final List<String> loadedFolderIds = <String>[];
  List<String>? applied;
  AutoRotateStatus statusValue = const AutoRotateStatus();
  ({bool found, List<String> urls})? folderResult = (found: true, urls: _folderUrls);
  final Map<String, ({bool found, List<String> urls})?> folderResults = <String, ({bool found, List<String> urls})?>{};
  List<String>? appliedAfterStart;
  List<String>? resolvedOverride;
  List<String> remoteUrls = const <String>[];
  Completer<void>? folderGate;
  Completer<void>? folderLoadEntered;
  int starts = 0;
  int stops = 0;

  @override
  Future<AutoRotateConfig> loadConfig({String? ownerId}) async => config;

  @override
  Future<void> saveConfig(AutoRotateConfig config, {String? ownerId}) async => this.config = config;

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    starts++;
    applied = appliedAfterStart ?? imageUrls;
    statusValue = AutoRotateStatus(isRunning: true, totalCount: imageUrls.length, cachedCount: imageUrls.length);
    return true;
  }

  @override
  Future<bool> stop() async {
    stops++;
    applied = const <String>[];
    statusValue = const AutoRotateStatus();
    return true;
  }

  @override
  Future<AutoRotateStatus> status() async => statusValue;

  @override
  Future<bool> rotateNow() async => true;

  @override
  Future<List<String>> resolveSources(List<String> imageUrls) async => resolvedOverride ?? imageUrls;

  @override
  Future<List<String>?> loadAppliedSources() async => applied;

  @override
  Future<List<String>> listDownloads() async => const <String>[];

  @override
  Future<List<String>?> loadRemoteUrls(AutoRotateSource source, {String? category}) async => remoteUrls;

  @override
  Future<({bool found, List<String> urls})?> loadFolderUrls(String folderId, {required String userId}) async {
    loadedOwners.add(userId);
    loadedFolderIds.add(folderId);
    if (folderLoadEntered case final Completer<void> entered when !entered.isCompleted) entered.complete();
    await folderGate?.future;
    return folderResults.containsKey(folderId) ? folderResults[folderId] : folderResult;
  }

  @override
  Future<Set<WallpaperTarget>> supportedTargets() async => WallpaperTarget.values.toSet();

  @override
  Future<bool> consumeBatteryTip() async => false;
}

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  test('reopening the screen reads the folder again inside the 15 minute window', () async {
    final _Repository repository = _Repository();
    final AutoRotateBloc bloc = AutoRotateBloc(repository)..clock = () => DateTime.utc(2026, 1, 1);

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.loadedOwners, <String>['account-a', 'account-a']);

    bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repository.loadedOwners, <String>['account-a', 'account-a', 'account-a']);
    await bloc.close();
  });

  test('a failed folder read is also throttled until the next 15 minute window', () async {
    final _Repository repository = _Repository()..folderResult = null;
    DateTime now = DateTime.utc(2026, 1, 1);
    final AutoRotateBloc bloc = AutoRotateBloc(repository)..clock = () => now;

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.loadedOwners, <String>['account-a']);

    now = now.add(const Duration(minutes: 10));
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.loadedOwners, <String>['account-a']);

    now = now.add(const Duration(minutes: 5));
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.loadedOwners, <String>['account-a', 'account-a']);
    await bloc.close();
  });

  test('a failed switch to another folder preserves the selected folder recheck timestamp', () async {
    final _Repository repository = _Repository()
      ..config = const AutoRotateConfig(enabled: true, source: AutoRotateSource.folder, folderId: 'folder-a');
    DateTime now = DateTime.utc(2026, 1, 1);
    final AutoRotateBloc bloc = AutoRotateBloc(repository)..clock = () => now;

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.loadedFolderIds, <String>['folder-a']);

    now = now.add(const Duration(minutes: 14));
    repository.folderResults['folder-b'] = (found: false, urls: const <String>[]);
    bloc.add(const AutoRotateEvent.folderChosen(folderId: 'folder-b', name: 'Missing folder'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(bloc.state.config.folderId, 'folder-a');

    now = now.add(const Duration(minutes: 1));
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repository.loadedFolderIds, <String>['folder-a', 'folder-b', 'folder-a']);
    await bloc.close();
  });

  test('deletion during a pending folder refresh stops and clears the rotation', () async {
    final _Repository repository = _Repository();
    final AutoRotateBloc bloc = AutoRotateBloc(repository)..favouritesDebounce = Duration.zero;

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.starts, 1);

    repository
      ..folderResults['folder-a'] = (found: false, urls: const <String>[])
      ..folderGate = Completer<void>()
      ..folderLoadEntered = Completer<void>();
    bloc.add(const AutoRotateEvent.folderChanged(folderId: 'folder-a', name: 'Private folder'));
    await repository.folderLoadEntered!.future;
    bloc.add(const AutoRotateEvent.folderChanged(folderId: 'folder-a'));
    repository.folderGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(repository.stops, 1);
    expect(repository.starts, 1);
    expect(bloc.state.config.source, AutoRotateSource.favourites);
    expect(bloc.state.config.enabled, isFalse);
    expect(bloc.state.status.isRunning, isFalse);
    expect(bloc.state.folderStop?.reason, AutoRotateStopReason.folderDeleted);
    await bloc.close();
  });

  test('changing accounts clears the prior owner folder URLs from state', () async {
    final _Repository repository = _Repository();
    final AutoRotateBloc bloc = AutoRotateBloc(repository);

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(bloc.state.remoteCount, _folderUrls.length);

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-b'));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(bloc.state.remoteCount, 0);
    expect(repository.loadedOwners, <String>['account-a', 'account-a']);
    await bloc.close();
  });

  test('startup comparison uses the source list accepted by the platform', () async {
    final _Repository repository = _Repository()
      ..config = const AutoRotateConfig(enabled: true)
      ..appliedAfterStart = _resolvedFavouriteUrls
      ..resolvedOverride = _resolvedFavouriteUrls;
    final AutoRotateBloc bloc = AutoRotateBloc(repository);

    bloc.add(const AutoRotateEvent.started(favouriteUrls: _favouriteUrls, isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.starts, 1);

    bloc.add(const AutoRotateEvent.started(favouriteUrls: _favouriteUrls, isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repository.starts, 1);
    await bloc.close();
  });

  test('source resolution enforces the minimum playlist size before native start', () async {
    final _Repository repository = _Repository()
      ..config = const AutoRotateConfig(enabled: true)
      ..resolvedOverride = <String>['/app/files/one.jpg'];
    final AutoRotateBloc bloc = AutoRotateBloc(repository);

    bloc.add(const AutoRotateEvent.started(favouriteUrls: _favouriteUrls, isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repository.starts, 0);
    expect(repository.stops, 1);
    expect(bloc.state.config.enabled, isFalse);
    expect(bloc.state.status.isRunning, isFalse);
    await bloc.close();
  });

  test('a folder read for a prior account cannot start rotation after an account switch', () async {
    final _Repository repository = _Repository()
      ..folderGate = Completer<void>()
      ..folderLoadEntered = Completer<void>();
    final AutoRotateBloc bloc = AutoRotateBloc(repository);

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await repository.folderLoadEntered!.future;
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-b'));
    repository.folderGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repository.starts, 0);
    expect(bloc.state.config.enabled, isFalse);
    await bloc.close();
  });

  test('an A-B-A switch retries a stale pending initial folder read for account A', () async {
    final _Repository repository = _Repository()
      ..config = const AutoRotateConfig(
        enabled: false,
        source: AutoRotateSource.folder,
        folderId: 'folder-a',
        folderName: 'Private folder',
      )
      ..folderGate = Completer<void>()
      ..folderLoadEntered = Completer<void>();
    final AutoRotateBloc bloc = AutoRotateBloc(repository);

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    repository.config = const AutoRotateConfig(
      enabled: true,
      source: AutoRotateSource.folder,
      folderId: 'folder-a',
      folderName: 'Private folder',
    );
    bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
    await repository.folderLoadEntered!.future;

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-b'));
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    repository.folderGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(repository.loadedOwners, <String>['account-a', 'account-a']);
    expect(bloc.state.config.enabled, isTrue);
    expect(bloc.state.remoteCount, _folderUrls.length);
    expect(bloc.state.sourceLoadFailed, isFalse);
    expect(bloc.state.folderStop, isNull);
    expect(repository.starts, 1);
    await bloc.close();
  });

  test('favourites updates preserve a rejected folder intent and its retry notice', () async {
    final _Repository repository = _Repository()..folderResults['folder-b'] = null;
    final AutoRotateBloc bloc = AutoRotateBloc(repository);

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    bloc.add(const AutoRotateEvent.folderChosen(folderId: 'folder-b', name: 'Other folder'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(bloc.state.config.folderId, 'folder-a');
    expect(bloc.state.sourceLoadFailed, isTrue);

    bloc.add(const AutoRotateEvent.favouritesChanged(_favouriteUrls));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(bloc.state.config.folderId, 'folder-a');
    expect(bloc.state.favouriteCount, _favouriteUrls.length);
    expect(bloc.state.sourceLoadFailed, isTrue);
    repository.folderResults['folder-b'] = (found: true, urls: _folderUrls);
    bloc.add(const AutoRotateEvent.toggled(true));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(repository.loadedFolderIds, <String>['folder-a', 'folder-b', 'folder-b']);
    expect(bloc.state.config.folderId, 'folder-b');
    expect(bloc.state.sourceLoadFailed, isFalse);
    await bloc.close();
  });

  test('queued folder selection and enable events cannot run under a changed account', () async {
    final _Repository repository = _Repository()
      ..config = const AutoRotateConfig(
        enabled: false,
        source: AutoRotateSource.folder,
        folderId: 'folder-a',
        folderName: 'Private folder',
      );
    final AutoRotateBloc bloc = AutoRotateBloc(repository)..favouritesDebounce = Duration.zero;

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(repository.loadedOwners, <String>['account-a']);
    expect(bloc.state.loaded, isTrue);

    repository
      ..folderGate = Completer<void>()
      ..folderLoadEntered = Completer<void>();
    bloc.add(const AutoRotateEvent.folderChanged(folderId: 'folder-a', name: 'Private folder'));
    await repository.folderLoadEntered!.future;
    bloc.add(const AutoRotateEvent.folderChosen(folderId: 'folder-b', name: 'Other folder', enable: true));
    bloc.add(const AutoRotateEvent.toggled(true));
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-b'));
    repository.folderGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(repository.loadedOwners, <String>['account-a', 'account-a']);
    expect(repository.starts, 0);
    expect(bloc.state.config.enabled, isFalse);
    expect(bloc.state.config.folderId, 'folder-a');
    await bloc.close();
  });

  test('a pending folder selection cannot replace another source cache across accounts', () async {
    const List<String> categoryUrls = <String>[
      'https://example.com/category-one.jpg',
      'https://example.com/category-two.jpg',
    ];
    final _Repository repository = _Repository()
      ..config = const AutoRotateConfig(enabled: true, source: AutoRotateSource.category)
      ..remoteUrls = categoryUrls;
    final AutoRotateBloc bloc = AutoRotateBloc(repository);

    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a'));
    bloc.add(const AutoRotateEvent.started(favouriteUrls: <String>[], isPro: true));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(bloc.state.remoteCount, categoryUrls.length);
    expect(repository.starts, 1);

    repository
      ..folderGate = Completer<void>()
      ..folderLoadEntered = Completer<void>();
    bloc.add(const AutoRotateEvent.folderChosen(folderId: 'private-folder', name: 'Private folder'));
    await repository.folderLoadEntered!.future;
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-b'));
    repository.folderGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.config.source, AutoRotateSource.category);
    expect(bloc.state.config.enabled, isFalse);
    expect(bloc.state.remoteCount, 0);
    expect(repository.loadedOwners, <String>['account-a']);
    expect(repository.starts, 1);
    await bloc.close();
  });
}
