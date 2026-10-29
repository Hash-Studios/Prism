import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/following_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/prism_feed/biz/bloc/latest_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockPersonalizedRepository extends Mock implements PersonalizedFeedRepository {}

PrismWallpaper _wall(String id) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://example.com/$id.jpg',
    thumbnailUrl: 'https://example.com/$id-thumb.jpg',
  ),
);

PersonalizedFeedPage _page(List<String> ids, {bool hasMore = false}) => PersonalizedFeedPage(
  items: ids.map((id) => PrismFeedItem(id: id, wallpaper: _wall(id))).toList(),
  hasMore: hasMore,
);

/// Serves fixed pages. Ids that start with `ai` are AI walls.
class _ScriptedFeedBloc extends PagedFeedBloc {
  _ScriptedFeedBloc(this.pages, {Set<int>? failedPages, this.pageSequences, this.pendingLoads})
    : failedPages = failedPages ?? <int>{},
      super(surface: AnalyticsSurfaceValue.values.first, sourceContext: 'test_scripted');

  final Map<int, PersonalizedFeedPage> pages;
  final Set<int> failedPages;
  final Map<int, List<PersonalizedFeedPage>>? pageSequences;
  final Map<int, Completer<Result<PersonalizedFeedPage>>>? pendingLoads;
  final List<int> requested = <int>[];

  @override
  Future<Result<PersonalizedFeedPage>> loadPage(int page) async {
    requested.add(page);
    if (failedPages.remove(page)) return Result.error(const NetworkFailure('offline'));
    final Completer<Result<PersonalizedFeedPage>>? pending = pendingLoads?.remove(page);
    if (pending != null) return pending.future;
    final List<PersonalizedFeedPage>? sequence = pageSequences?[page];
    if (sequence != null && sequence.isNotEmpty) return Result.success(sequence.removeAt(0));
    return Result.success(pages[page]!);
  }
}

PersonalizedFeedPage _mixedPage(List<String> ids, {bool hasMore = true}) => PersonalizedFeedPage(
  items: ids
      .map(
        (id) => PrismFeedItem(
          id: id,
          wallpaper: PrismWallpaper(core: _wall(id).core, isAiGenerated: id.startsWith('ai')),
        ),
      )
      .toList(),
  hasMore: hasMore,
);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  group('LatestFeedBloc', () {
    late _MockPrismRepository repository;

    setUp(() {
      repository = _MockPrismRepository();
    });

    test('loads the newest walls as feed items and reports the load', () async {
      when(
        () => repository.fetchFeed(refresh: true),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('a'), _wall('b')]));
      when(() => repository.hasMore).thenReturn(true);
      final bloc = LatestFeedBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();

      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.map((e) => e.id), <String>['a', 'b']);
      expect(bloc.state.hasMore, isTrue);
      final event = analytics.events.whereType<SurfaceContentLoadedEvent>().single;
      expect(event.surface, AnalyticsSurfaceValue.homeLatestGrid);
      expect(event.itemCount, 2);
    });

    test('starting twice loads once', () async {
      when(
        () => repository.fetchFeed(refresh: true),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('a')]));
      when(() => repository.hasMore).thenReturn(false);
      final bloc = LatestFeedBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      bloc.add(const PagedFeedEvent.started());
      await _settle();

      verify(() => repository.fetchFeed(refresh: true)).called(1);
    });

    test('fetching more appends the next page once and stops when the repository has no more', () async {
      when(
        () => repository.fetchFeed(refresh: true),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('a'), _wall('b')]));
      when(
        () => repository.fetchFeed(refresh: false),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('b'), _wall('c')]));
      when(() => repository.hasMore).thenReturn(true);
      final bloc = LatestFeedBloc(repository);
      addTearDown(bloc.close);
      bloc.add(const PagedFeedEvent.started());
      await _settle();
      when(() => repository.hasMore).thenReturn(false);

      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      await _settle();
      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      await _settle();

      expect(bloc.state.items.map((e) => e.id), <String>['a', 'b', 'c']);
      expect(bloc.state.page, 2);
      expect(bloc.state.hasMore, isFalse);
      verify(() => repository.fetchFeed(refresh: false)).called(1);
    });

    test('a failed first load is a failure with nothing to show', () async {
      when(
        () => repository.fetchFeed(refresh: true),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final bloc = LatestFeedBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();

      expect(bloc.state.status, LoadStatus.failure);
      expect(bloc.state.items, isEmpty);
      expect(analytics.events.whereType<SurfaceContentLoadedEvent>().single.result, EventResultValue.failure);
    });

    test('a failed page keeps the items and keeps hasMore for a retry', () async {
      when(
        () => repository.fetchFeed(refresh: true),
      ).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('a')]));
      when(
        () => repository.fetchFeed(refresh: false),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      when(() => repository.hasMore).thenReturn(true);
      final bloc = LatestFeedBloc(repository);
      addTearDown(bloc.close);
      bloc.add(const PagedFeedEvent.started());
      await _settle();

      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      await _settle();

      expect(bloc.state.items.map((e) => e.id), <String>['a']);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.actionStatus, ActionStatus.failure);
    });

    test('a failed refresh keeps the items on screen', () async {
      int calls = 0;
      when(() => repository.fetchFeed(refresh: true)).thenAnswer(
        (_) async =>
            ++calls == 1 ? Result.success(<PrismWallpaper>[_wall('a')]) : Result.error(const NetworkFailure('offline')),
      );
      when(() => repository.hasMore).thenReturn(true);
      final bloc = LatestFeedBloc(repository);
      addTearDown(bloc.close);
      bloc.add(const PagedFeedEvent.started());
      await _settle();

      bloc.add(const PagedFeedEvent.refreshRequested());
      await _settle();

      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.map((e) => e.id), <String>['a']);
    });
  });

  group('FollowingFeedBloc', () {
    test('asks the repository for each page in turn', () async {
      final repository = _MockPersonalizedRepository();
      when(
        () => repository.fetchFollowing(page: 1),
      ).thenAnswer((_) async => Result.success(_page(<String>['a'], hasMore: true)));
      when(() => repository.fetchFollowing(page: 2)).thenAnswer((_) async => Result.success(_page(<String>['a', 'b'])));
      final bloc = FollowingFeedBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      await _settle();

      expect(bloc.state.items.map((e) => e.id), <String>['a', 'b']);
      expect(bloc.state.hasMore, isFalse);
      expect(
        analytics.events.whereType<SurfaceContentLoadedEvent>().first.surface,
        AnalyticsSurfaceValue.homeFollowingGrid,
      );
    });

    test('a user who follows nobody gets an empty, loaded list', () async {
      final repository = _MockPersonalizedRepository();
      when(() => repository.fetchFollowing(page: 1)).thenAnswer((_) async => Result.success(_page(<String>[])));
      final bloc = FollowingFeedBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();

      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items, isEmpty);
      expect(analytics.events.whereType<SurfaceContentLoadedEvent>().single.result, EventResultValue.empty);
    });
  });

  group('PopularFeedBloc', () {
    test('loads one page and never pages on', () async {
      final repository = _MockPersonalizedRepository();
      when(() => repository.fetchPopular()).thenAnswer((_) async => Result.success(_page(<String>['a', 'b'])));
      final bloc = PopularFeedBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      await _settle();

      expect(bloc.state.items.map((e) => e.id), <String>['a', 'b']);
      verify(() => repository.fetchPopular()).called(1);
      expect(
        analytics.events.whereType<SurfaceContentLoadedEvent>().single.surface,
        AnalyticsSurfaceValue.homePopularGrid,
      );
    });
  });

  group('AI walls hidden', () {
    setUp(() async {
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      await AiContentFilter.setShowsAi(settings, false);
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
    });
    tearDown(() => getIt.unregister<SettingsLocalDataSource>());

    test('a prefiltered empty page still loads the next page to fill the feed', () async {
      final repository = _MockPersonalizedRepository();
      when(
        () => repository.fetchFollowing(page: 1),
      ).thenAnswer((_) async => Result.success(_page(<String>[], hasMore: true)));
      when(
        () => repository.fetchFollowing(page: 2),
      ).thenAnswer((_) async => Result.success(_page(<String>['human-2'])));
      final bloc = FollowingFeedBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      verifyInOrder(<void Function()>[
        () => repository.fetchFollowing(page: 1),
        () => repository.fetchFollowing(page: 2),
      ]);
      expect(bloc.state.items.map((item) => item.id), <String>['human-2']);
      expect(bloc.state.page, 2);
    });

    test('a first page of only AI walls loads the next page instead of stalling', () async {
      final bloc = _ScriptedFeedBloc(<int, PersonalizedFeedPage>{
        1: _mixedPage(<String>['ai-1', 'ai-2']),
        2: _mixedPage(<String>['ai-3', 'human-4'], hasMore: false),
      });
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      await _settle();

      expect(bloc.requested, <int>[1, 2]);
      expect(bloc.state.page, 2);
      expect(bloc.state.items.map((item) => item.id), <String>['ai-1', 'ai-2', 'ai-3', 'human-4']);
      expect(bloc.state.hasMore, isFalse);
    });

    test('fetching more skips AI-only pages, at most five pages per request', () async {
      final bloc = _ScriptedFeedBloc(<int, PersonalizedFeedPage>{
        1: _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-1-$i']),
        for (int page = 2; page <= 8; page++) page: _mixedPage(<String>['ai-$page']),
      });
      addTearDown(bloc.close);
      bloc.add(const PagedFeedEvent.started());
      await _settle();

      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      for (int i = 0; i < 6; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2, 3, 4, 5, 6]);
      expect(bloc.state.page, 6);
      expect(bloc.state.hasMore, isTrue);
    });

    test('a short first page thinned by AI walls fetches more until it can fill the screen', () async {
      final bloc = _ScriptedFeedBloc(<int, PersonalizedFeedPage>{
        1: _mixedPage(<String>['human-1', 'ai-1', 'ai-2']),
        2: _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-2-$i', 'ai-3']),
        3: _mixedPage(<String>['human-3']),
      });
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2], reason: '13 visible walls after page 2 is enough');
      expect(bloc.state.page, 2);
      expect(bloc.state.items, hasLength(16));
    });

    test('merging hidden pages keeps each wallpaper once', () async {
      final bloc = _ScriptedFeedBloc(<int, PersonalizedFeedPage>{
        1: _mixedPage(<String>['human-1', 'ai-1']),
        2: _mixedPage(<String>['human-1', 'human-2'], hasMore: false),
      });
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2]);
      expect(bloc.state.items.map((item) => item.id), <String>['human-1', 'ai-1', 'human-2']);
    });

    test('duplicate ids do not count toward the visible-page fill target', () async {
      final bloc = _ScriptedFeedBloc(<int, PersonalizedFeedPage>{
        1: _mixedPage(<String>[...List<String>.filled(12, 'human-1'), 'ai-1']),
        2: _mixedPage(<String>['human-2'], hasMore: false),
      });
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2]);
      expect(bloc.state.items.map((item) => item.id), <String>['human-1', 'ai-1', 'human-2']);
    });

    test('a request started with AI shown loads one page even if the setting changes', () async {
      await AiContentFilter.setShowsAi(getIt<SettingsLocalDataSource>(), true);
      final Completer<Result<PersonalizedFeedPage>> pendingPage = Completer<Result<PersonalizedFeedPage>>();
      final bloc = _ScriptedFeedBloc(
        <int, PersonalizedFeedPage>{
          2: _mixedPage(<String>['ai-2'], hasMore: false),
        },
        pendingLoads: <int, Completer<Result<PersonalizedFeedPage>>>{1: pendingPage},
      );
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      await AiContentFilter.setShowsAi(getIt<SettingsLocalDataSource>(), false);
      pendingPage.complete(Result.success(_mixedPage(<String>['ai-1'])));
      await _settle();

      expect(bloc.requested, <int>[1]);
    });

    test('AI-hidden page failure preserves progress and retries the same page', () async {
      final bloc = _ScriptedFeedBloc(
        <int, PersonalizedFeedPage>{
          1: _mixedPage(<String>['human-1', 'ai-1']),
          2: _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-2-$i'], hasMore: false),
        },
        failedPages: <int>{2},
      );
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2]);
      expect(bloc.state.page, 1);
      expect(bloc.state.items.map((item) => item.id), <String>['human-1', 'ai-1']);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.actionStatus, ActionStatus.failure);
      expect(bloc.state.failure, isA<NetworkFailure>());

      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2, 2]);
      expect(bloc.state.page, 2);
      expect(bloc.state.items, hasLength(14));
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.actionStatus, ActionStatus.success);
      expect(bloc.state.failure, isNull);
    });

    test('a later hidden-page failure keeps fetched pages and retries the next page', () async {
      final bloc = _ScriptedFeedBloc(
        <int, PersonalizedFeedPage>{
          1: _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-1-$i']),
          2: _mixedPage(<String>['ai-2']),
          3: _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-3-$i'], hasMore: false),
        },
        failedPages: <int>{3},
      );
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }
      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2, 3]);
      expect(bloc.state.page, 2);
      expect(bloc.state.items, hasLength(13));
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.actionStatus, ActionStatus.failure);
      expect(bloc.state.failure, isA<NetworkFailure>());

      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2, 3, 3]);
      expect(bloc.state.page, 3);
      expect(bloc.state.items, hasLength(25));
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.actionStatus, ActionStatus.success);
      expect(bloc.state.failure, isNull);
    });

    test('an empty fetched page advances the retry cursor after the next page fails', () async {
      final bloc = _ScriptedFeedBloc(
        <int, PersonalizedFeedPage>{
          1: _mixedPage(<String>[]),
          2: _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-2-$i'], hasMore: false),
        },
        failedPages: <int>{2},
      );
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2]);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.page, 1);
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.actionStatus, ActionStatus.failure);

      bloc.add(const PagedFeedEvent.fetchMoreRequested());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2, 2]);
      expect(bloc.state.page, 2);
      expect(bloc.state.items, hasLength(12));
      expect(bloc.state.actionStatus, ActionStatus.success);
    });

    test('an empty page with AI shown still requests exactly one page', () async {
      await AiContentFilter.setShowsAi(getIt<SettingsLocalDataSource>(), true);
      final bloc = _ScriptedFeedBloc(<int, PersonalizedFeedPage>{
        1: _mixedPage(<String>[]),
        2: _mixedPage(<String>['human-2']),
      });
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1]);
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.hasMore, isTrue);
    });

    test('a refresh supersedes a pending hidden-page scan', () async {
      final Completer<Result<PersonalizedFeedPage>> pendingPage = Completer<Result<PersonalizedFeedPage>>();
      final PersonalizedFeedPage firstPage = _mixedPage(<String>['human-old', 'ai-old']);
      final PersonalizedFeedPage refreshedPage = _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-new-$i']);
      final bloc = _ScriptedFeedBloc(
        <int, PersonalizedFeedPage>{
          1: refreshedPage,
          2: _mixedPage(<String>['human-stale']),
          3: _mixedPage(<String>['human-stale-2']),
        },
        pageSequences: <int, List<PersonalizedFeedPage>>{
          1: <PersonalizedFeedPage>[firstPage, refreshedPage],
        },
        pendingLoads: <int, Completer<Result<PersonalizedFeedPage>>>{2: pendingPage},
      );
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      expect(bloc.requested, <int>[1, 2]);

      bloc.add(const PagedFeedEvent.refreshRequested());
      await _settle();
      expect(bloc.state.items.map((item) => item.id), refreshedPage.items.map((item) => item.id));
      pendingPage.complete(Result.success(_mixedPage(<String>['human-stale'])));
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2, 1]);
      expect(bloc.state.items.map((item) => item.id), refreshedPage.items.map((item) => item.id));
      expect(bloc.state.page, 1);
    });

    test('closing during a hidden-page scan prevents more page requests', () async {
      final Completer<Result<PersonalizedFeedPage>> pendingPage = Completer<Result<PersonalizedFeedPage>>();
      final bloc = _ScriptedFeedBloc(
        <int, PersonalizedFeedPage>{
          1: _mixedPage(<String>['human-1', 'ai-1']),
          2: _mixedPage(<String>['human-2']),
          3: _mixedPage(<String>['human-3']),
        },
        pendingLoads: <int, Completer<Result<PersonalizedFeedPage>>>{2: pendingPage},
      );

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      expect(bloc.requested, <int>[1, 2]);
      final Future<void> close = bloc.close();
      pendingPage.complete(Result.success(_mixedPage(<String>['human-2'])));
      await close;
      for (int i = 0; i < 4; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2]);
    });

    test('overlapping fetch-more events start only one page scan', () async {
      final Completer<Result<PersonalizedFeedPage>> pendingPage = Completer<Result<PersonalizedFeedPage>>();
      final bloc = _ScriptedFeedBloc(
        <int, PersonalizedFeedPage>{
          1: _mixedPage(<String>[for (int i = 0; i < 12; i++) 'human-1-$i']),
          for (int page = 2; page <= 8; page++) page: _mixedPage(<String>['ai-$page']),
        },
        pendingLoads: <int, Completer<Result<PersonalizedFeedPage>>>{2: pendingPage},
      );
      addTearDown(bloc.close);

      bloc.add(const PagedFeedEvent.started());
      await _settle();
      bloc
        ..add(const PagedFeedEvent.fetchMoreRequested())
        ..add(const PagedFeedEvent.fetchMoreRequested());
      await _settle();
      expect(bloc.requested, <int>[1, 2]);
      pendingPage.complete(Result.success(_mixedPage(<String>['ai-2'])));
      for (int i = 0; i < 6; i++) {
        await _settle();
      }

      expect(bloc.requested, <int>[1, 2, 3, 4, 5, 6]);
      expect(bloc.state.page, 6);
    });
  });
}
