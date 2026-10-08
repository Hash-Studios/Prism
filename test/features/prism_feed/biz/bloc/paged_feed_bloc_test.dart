import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
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
}
