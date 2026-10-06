import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/fake_user_block_repository.dart';

class _MockFetchPersonalizedFeedUseCase extends Mock implements FetchPersonalizedFeedUseCase {}

class _MockPersonalizedFeedRepository extends Mock implements PersonalizedFeedRepository {}

FeedItemEntity _prismItem(String id, {required String authorEmail, String? fullUrl}) {
  return FeedItemEntity.prism(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: fullUrl ?? 'https://example.com/$id.jpg',
        thumbnailUrl: 'https://example.com/$id-thumb.jpg',
        authorEmail: authorEmail,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_prismItem('fallback', authorEmail: 'f@example.com'));
    registerFallbackValue(
      const FetchPersonalizedFeedRequest(
        page: 1,
        refresh: true,
        seenKeys: <String>[],
        existingItems: <FeedItemEntity>[],
      ),
    );
  });

  late _MockFetchPersonalizedFeedUseCase fetchUseCase;
  late _MockPersonalizedFeedRepository repository;

  setUp(() {
    fetchUseCase = _MockFetchPersonalizedFeedUseCase();
    repository = _MockPersonalizedFeedRepository();
    when(() => repository.lessLikeThis(any())).thenAnswer((_) async {});
  });

  test('blocking a creator removes their items from the emitted state without a refetch', () async {
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(
        PersonalizedFeedPage(
          items: <FeedItemEntity>[
            _prismItem('1', authorEmail: 'blocked@example.com'),
            _prismItem('2', authorEmail: 'kept@example.com'),
          ],
          hasMore: false,
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending();
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, blockRepo);
    addTearDown(bloc.close);

    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);

    blockRepo.completeInitial(<String>{});
    await Future<void>.delayed(Duration.zero);
    blockRepo.completeInitial(<String>{'blocked@example.com'});
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((e) => e.id), <String>['2']);
    verify(() => fetchUseCase(any())).called(1);
  });

  test('less like this removes the item and reports it to the repository', () async {
    final FeedItemEntity item1 = _prismItem('1', authorEmail: 'a@example.com');
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(
        PersonalizedFeedPage(
          items: <FeedItemEntity>[
            item1,
            _prismItem('2', authorEmail: 'b@example.com'),
          ],
          hasMore: false,
        ),
      ),
    );
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);

    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);

    bloc.add(PersonalizedFeedEvent.lessLikeThisRequested(item1));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((e) => e.id), <String>['2']);
    verify(() => repository.lessLikeThis(item1)).called(1);
  });

  for (final bool emptyUrl in <bool>[false, true]) {
    test('less like this uses canonical identity with ${emptyUrl ? 'empty' : 'normalized'} URLs', () async {
      final item = _prismItem('1', authorEmail: 'a@example.com', fullUrl: emptyUrl ? '' : 'https://example.com/1.jpg');
      final selected = _prismItem(
        '1',
        authorEmail: 'a@example.com',
        fullUrl: emptyUrl ? '' : ' HTTPS://EXAMPLE.COM/1.JPG ',
      );
      final kept = _prismItem('2', authorEmail: 'b@example.com', fullUrl: emptyUrl ? '' : null);
      when(() => fetchUseCase(any())).thenAnswer(
        (_) async => Result.success(PersonalizedFeedPage(items: <FeedItemEntity>[item, kept], hasMore: false)),
      );
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items.map((item) => item.id), <String>['1', '2']);
      bloc.add(PersonalizedFeedEvent.lessLikeThisRequested(selected));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((item) => item.id), <String>['2']);
    });
  }

  test('late initial response cannot replace a newer preference refresh', () async {
    final Completer<Result<PersonalizedFeedPage>> initial = Completer<Result<PersonalizedFeedPage>>();
    final Completer<Result<PersonalizedFeedPage>> refreshed = Completer<Result<PersonalizedFeedPage>>();
    var calls = 0;
    when(() => fetchUseCase(any())).thenAnswer((_) => ++calls == 1 ? initial.future : refreshed.future);
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);

    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PersonalizedFeedEvent.refreshRequested());
    await Future<void>.delayed(Duration.zero);

    refreshed.complete(
      Result.success(
        PersonalizedFeedPage(
          items: <FeedItemEntity>[_prismItem('new', authorEmail: 'new@example.com')],
          hasMore: false,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    initial.complete(
      Result.success(
        PersonalizedFeedPage(
          items: <FeedItemEntity>[_prismItem('old', authorEmail: 'old@example.com')],
          hasMore: false,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((item) => item.id), <String>['new']);
  });

  test('late load-more response cannot append items from before a refresh', () async {
    final Completer<Result<PersonalizedFeedPage>> loadMore = Completer<Result<PersonalizedFeedPage>>();
    var calls = 0;
    when(() => fetchUseCase(any())).thenAnswer((_) {
      calls += 1;
      if (calls == 2) return loadMore.future;
      final String id = calls == 1 ? 'initial' : 'fresh';
      return Future<Result<PersonalizedFeedPage>>.value(
        Result.success(
          PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem(id, authorEmail: '$id@example.com')], hasMore: true),
        ),
      );
    });
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);

    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PersonalizedFeedEvent.refreshRequested());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    loadMore.complete(
      Result.success(
        PersonalizedFeedPage(
          items: <FeedItemEntity>[_prismItem('stale', authorEmail: 'stale@example.com')],
          hasMore: true,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((item) => item.id), <String>['fresh']);
    expect(bloc.state.page, 1);
  });

  test('the first load and a refresh report their own source context', () async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(
        PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem('1', authorEmail: 'kept@example.com')], hasMore: false),
      ),
    );
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);

    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PersonalizedFeedEvent.refreshRequested());
    await Future<void>.delayed(Duration.zero);

    expect(analytics.events.whereType<SurfaceContentLoadedEvent>().map((event) => event.sourceContext), <String>[
      'personalized_feed_initial',
      'personalized_feed_refresh',
    ]);
  });

  test('fetching more advances the page and keeps one copy of a repeated wallpaper', () async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    when(() => fetchUseCase(any())).thenAnswer((invocation) async {
      final request = invocation.positionalArguments.single as FetchPersonalizedFeedRequest;
      final ids = request.page == 1 ? <String>['1', '2'] : <String>['2', '3'];
      return Result.success(
        PersonalizedFeedPage(
          items: <FeedItemEntity>[for (final id in ids) _prismItem(id, authorEmail: 'kept@example.com')],
          hasMore: request.page == 1,
          usedKeys: ids,
        ),
      );
    });
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);

    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.page, 2);
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2', '3']);
    expect(bloc.state.hasMore, isFalse);
  });

  group('refresh', () {
    PersonalizedFeedPage page(List<String> ids) => PersonalizedFeedPage(
      items: ids.map((id) => _prismItem(id, authorEmail: '$id@example.com')).toList(),
      hasMore: true,
    );

    test('keeps the old items on screen until the new ones arrive', () async {
      final Completer<Result<PersonalizedFeedPage>> refreshed = Completer<Result<PersonalizedFeedPage>>();
      int calls = 0;
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) => ++calls == 1 ? Future.value(Result.success(page(<String>['1', '2']))) : refreshed.future);
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);
      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const PersonalizedFeedEvent.refreshRequested());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, LoadStatus.loading);
      expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);

      refreshed.complete(Result.success(page(<String>['3'])));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.map((e) => e.id), <String>['3']);
    });

    test('a failed refresh keeps the old items and reports the failure', () async {
      int calls = 0;
      when(() => fetchUseCase(any())).thenAnswer(
        (_) async => ++calls == 1 ? Result.success(page(<String>['1', '2'])) : Result.error(const NetworkFailure('x')),
      );
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);
      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const PersonalizedFeedEvent.refreshRequested());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.actionStatus, ActionStatus.failure);
    });

    test('a failed first load with nothing to show is a failure state', () async {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const NetworkFailure('x')));
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, LoadStatus.failure);
      expect(bloc.state.items, isEmpty);
    });
  });
}
