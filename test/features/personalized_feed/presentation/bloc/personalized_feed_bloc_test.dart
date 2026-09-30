import 'dart:async';

import 'package:Prism/core/utils/result.dart';
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

import '../../../../support/fake_user_block_repository.dart';

class _MockFetchPersonalizedFeedUseCase extends Mock implements FetchPersonalizedFeedUseCase {}

class _MockPersonalizedFeedRepository extends Mock implements PersonalizedFeedRepository {}

FeedItemEntity _prismItem(String id, {required String authorEmail}) {
  return FeedItemEntity.prism(
    id: id,
    wallpaper: PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.com/$id.jpg',
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
}
