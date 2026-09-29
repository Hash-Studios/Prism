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
    when(() => repository.readPersistedSeenKeys()).thenAnswer((_) async => const <String>[]);
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
}
