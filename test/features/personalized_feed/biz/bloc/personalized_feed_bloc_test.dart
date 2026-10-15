// ignore_for_file: depend_on_referenced_packages

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
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/domain/entities/personalized_feed_page.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:fake_async/fake_async.dart';
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
    when(() => repository.undoLessLikeThis(any())).thenAnswer((_) async {});
    when(() => repository.readCached()).thenAnswer((_) async => null);
    when(() => repository.recordShown(any())).thenAnswer((_) async {});
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

  test('a failed page two keeps hasMore so the user can retry', () async {
    int calls = 0;
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => ++calls == 1
          ? Result.success(
              PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem('1', authorEmail: 'a@x.com')], hasMore: true),
            )
          : Result.error(const NetworkFailure('offline')),
    );
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);
    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.hasMore, isTrue);
    expect(bloc.state.actionStatus, ActionStatus.failure);
    expect(bloc.state.items.map((e) => e.id), <String>['1']);
    expect(bloc.state.page, 1);
  });

  group('instant home', () {
    PersonalizedFeedPage cachedPage({bool isStale = false}) => PersonalizedFeedPage(
      items: <FeedItemEntity>[_prismItem('cached', authorEmail: 'c@x.com')],
      hasMore: true,
      usedKeys: const <String>['cached'],
      isStale: isStale,
    );

    test('paints the cached page first, then replaces it with the fresh page', () async {
      final analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);
      when(() => repository.readCached()).thenAnswer((_) async => cachedPage());
      final Completer<Result<PersonalizedFeedPage>> fresh = Completer<Result<PersonalizedFeedPage>>();
      when(() => fetchUseCase(any())).thenAnswer((_) => fresh.future);
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);
      final List<PersonalizedFeedState> states = <PersonalizedFeedState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['cached']);
      expect(bloc.state.status, LoadStatus.loading);
      expect(bloc.state.isRefreshing, isTrue);
      expect(states.first.status, LoadStatus.success, reason: 'the cached page is shown as a loaded feed');
      expect(states.first.isRefreshing, isTrue);

      fresh.complete(
        Result.success(
          PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem('fresh', authorEmail: 'f@x.com')], hasMore: true),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['fresh']);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.isRefreshing, isFalse);
      expect(
        analytics.events.whereType<SurfaceContentLoadedEvent>().single.sourceContext,
        'personalized_feed_initial_cache_hit',
      );
    });

    test('tells a stale cache apart in the analytics context', () async {
      final analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);
      when(() => repository.readCached()).thenAnswer((_) async => cachedPage(isStale: true));
      when(
        () => fetchUseCase(any()),
      ).thenAnswer((_) async => Result.success(const PersonalizedFeedPage(items: <FeedItemEntity>[], hasMore: false)));
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        analytics.events.whereType<SurfaceContentLoadedEvent>().single.sourceContext,
        'personalized_feed_initial_cache_stale',
      );
    });

    test('keeps the cached page when the fresh load fails', () async {
      when(() => repository.readCached()).thenAnswer((_) async => cachedPage());
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['cached']);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.isRefreshing, isFalse);
      expect(bloc.state.refreshFailed, isTrue);
    });

    test('loads as before when nothing is cached or the cache cannot be read', () async {
      when(() => repository.readCached()).thenThrow(StateError('disk'));
      when(() => fetchUseCase(any())).thenAnswer(
        (_) async => Result.success(
          PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem('fresh', authorEmail: 'f@x.com')], hasMore: false),
        ),
      );
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);

      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['fresh']);
      expect(bloc.state.isRefreshing, isFalse);
    });
  });

  test('a changed content filter drops the items at once and loads page one again', () async {
    final Completer<Result<PersonalizedFeedPage>> fresh = Completer<Result<PersonalizedFeedPage>>();
    int calls = 0;
    when(() => fetchUseCase(any())).thenAnswer(
      (_) => ++calls == 1
          ? Future.value(
              Result.success(
                PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem('old', authorEmail: 'o@x.com')], hasMore: true),
              ),
            )
          : fresh.future,
    );
    final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
    addTearDown(bloc.close);
    bloc.add(const PersonalizedFeedEvent.started());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const PersonalizedFeedEvent.settingsChanged());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items, isEmpty);
    expect(bloc.state.status, LoadStatus.loading);

    fresh.complete(
      Result.success(
        PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem('new', authorEmail: 'n@x.com')], hasMore: true),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((e) => e.id), <String>['new']);
    verify(() => fetchUseCase(any())).called(2);
  });

  group('chip rail', () {
    test('selecting a chip keeps it in the state and reports the choice once', () async {
      final analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      addTearDown(AnalyticsRuntime.reset);
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);
      expect(bloc.state.chip, HomeFeedChip.forYou);

      bloc.add(const PersonalizedFeedEvent.chipSelected(HomeFeedChip.popular));
      bloc.add(const PersonalizedFeedEvent.chipSelected(HomeFeedChip.popular));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const PersonalizedFeedEvent.chipSelected(HomeFeedChip.latest));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.chip, HomeFeedChip.latest);
      final taps = analytics.events.whereType<SurfaceActionTappedEvent>().toList();
      expect(taps.map((e) => e.sourceContext), <String>['home_chip_popular', 'home_chip_latest']);
      expect(taps.every((e) => e.action == AnalyticsActionValue.homeChipSelected), isTrue);
    });

    test('a chip change does not reload the For you feed', () async {
      when(() => fetchUseCase(any())).thenAnswer(
        (_) async => Result.success(
          PersonalizedFeedPage(items: <FeedItemEntity>[_prismItem('1', authorEmail: 'a@x.com')], hasMore: false),
        ),
      );
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);
      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);

      bloc.add(const PersonalizedFeedEvent.chipSelected(HomeFeedChip.following));
      bloc.add(const PersonalizedFeedEvent.chipSelected(HomeFeedChip.forYou));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['1']);
      verify(() => fetchUseCase(any())).called(1);
    });
  });

  group('undo less like this', () {
    test('puts the wallpaper back where it was and shows it again', () async {
      final FeedItemEntity second = _prismItem('2', authorEmail: 'b@x.com');
      when(() => fetchUseCase(any())).thenAnswer(
        (_) async => Result.success(
          PersonalizedFeedPage(
            items: <FeedItemEntity>[
              _prismItem('1', authorEmail: 'a@x.com'),
              second,
              _prismItem('3', authorEmail: 'c@x.com'),
            ],
            hasMore: false,
          ),
        ),
      );
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);
      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);
      bloc.add(PersonalizedFeedEvent.lessLikeThisRequested(second));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items.map((e) => e.id), <String>['1', '3']);

      bloc.add(PersonalizedFeedEvent.lessLikeThisUndone(second, index: 1));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['1', '2', '3']);
      verifyInOrder(<void Function()>[
        () => repository.lessLikeThis(second),
        () => repository.undoLessLikeThis(second),
      ]);
    });
  });

  group('tiles seen', () {
    test('are reported once, in one batch a second after the first tile', () {
      fakeAsync((async) {
        final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
        bloc.add(const PersonalizedFeedEvent.tilesSeen(<String>['a']));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 600));
        bloc.add(const PersonalizedFeedEvent.tilesSeen(<String>['b', 'a']));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 399));
        verifyNever(() => repository.recordShown(any()));

        async.elapse(const Duration(milliseconds: 1));

        verify(() => repository.recordShown(<String>['a', 'b'])).called(1);

        bloc.add(const PersonalizedFeedEvent.tilesSeen(<String>['a']));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        verifyNever(() => repository.recordShown(<String>['a']));

        unawaited(bloc.close());
        async.flushMicrotasks();
      });
    });

    test('left unreported when the bloc closes are reported then', () {
      fakeAsync((async) {
        final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
        bloc.add(const PersonalizedFeedEvent.tilesSeen(<String>['x']));
        async.flushMicrotasks();

        unawaited(bloc.close());
        async.flushMicrotasks();

        verify(() => repository.recordShown(<String>['x'])).called(1);
      });
    });
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
      expect(bloc.state.refreshFailed, isTrue);
    });

    test('a failed refresh does not look like a failed page load, so paging carries on', () async {
      int calls = 0;
      when(() => fetchUseCase(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments.single as FetchPersonalizedFeedRequest;
        calls++;
        if (calls == 2) return Result.error(const NetworkFailure('x'));
        return Result.success(page(request.page == 1 ? <String>['1', '2'] : <String>['3']));
      });
      final bloc = PersonalizedFeedBloc(fetchUseCase, repository, FakeUserBlockRepository.pending());
      addTearDown(bloc.close);
      bloc.add(const PersonalizedFeedEvent.started());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const PersonalizedFeedEvent.refreshRequested());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.actionStatus, isNot(ActionStatus.failure));

      bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items.map((e) => e.id), <String>['1', '2', '3']);
      expect(bloc.state.refreshFailed, isFalse);
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
