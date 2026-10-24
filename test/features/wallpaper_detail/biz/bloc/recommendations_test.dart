import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/repositories/wallpaper_recommendation_repository_impl.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wallpaper_recommendation_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/in_memory_local_store.dart';

class _Prism extends Mock implements PrismWallpaperRepository {}

class _Blocks extends Mock implements UserBlockRepository {}

class _Firestore extends Fake implements FirestoreClient {
  final specs = <FirestoreQuerySpec>[];
  List<Map<String, dynamic>> rows = [];
  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    specs.add(spec);
    return rows.map((row) => map(row, 'doc-${row['id']}')).toList();
  }
}

class _Wallhaven extends Mock implements WallhavenWallpaperRepository {}

class _Pexels extends Mock implements PexelsWallpaperRepository {}

class _Views extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _Palette extends Mock implements PaletteRepository {}

class _Count extends Mock implements GetWallpaperSetCountUseCase {}

class _Recommendations implements WallpaperRecommendationRepository {
  final cursors = <RecommendationCursor?>[];
  final sessions = <String>[];
  final released = <String>[];
  late Future<RecommendationPage> Function(RecommendationCursor?) respond;
  @override
  Future<RecommendationPage> load({
    required FeedItemEntity current,
    required String sessionKey,
    RecommendationCursor? cursor,
  }) {
    cursors.add(cursor);
    sessions.add(sessionKey);
    return respond(cursor);
  }

  @override
  void release(String key) => released.add(key);
}

FeedItemEntity _item(String id, {bool prism = false}) {
  final core = WallpaperCore(
    id: id,
    source: prism ? WallpaperSource.prism : WallpaperSource.pexels,
    fullUrl: '',
    thumbnailUrl: '',
  );
  return prism
      ? PrismFeedItem(
          id: id,
          wallpaper: PrismWallpaper(core: core),
        )
      : PexelsFeedItem(
          id: id,
          wallpaper: PexelsWallpaper(core: core),
        );
}

void main() {
  late _Recommendations repository;
  late WallpaperDetailBloc bloc;
  setUp(() {
    repository = _Recommendations();
    bloc = WallpaperDetailBloc(_Prism(), _Wallhaven(), _Pexels(), _Views(), _Palette(), _Count(), null, repository);
  });
  tearDown(() async {
    if (!bloc.isClosed) await bloc.close();
  });
  Future<void> load() async {
    bloc.add(LoadFromEntity(entity: _item('current')));
    await pumpEventQueue();
  }

  WallpaperDetailLoaded getState() => bloc.state as WallpaperDetailLoaded;

  test('filtered-empty pages advance and identity is qualified by source', () async {
    repository.respond = (cursor) async => cursor == null
        ? RecommendationPage(
            items: [_item('current')],
            kind: RecommendationKind.discovery,
            nextCursor: const ExternalRecommendationCursor(2),
          )
        : RecommendationPage(
            items: [_item('a'), _item('a'), _item('a', prism: true)],
            kind: RecommendationKind.discovery,
          );
    await load();
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    expect(getState().recommendations.items.map((item) => (item.source, item.id)), [
      (WallpaperSource.pexels, 'a'),
      (WallpaperSource.prism, 'a'),
    ]);
    expect(getState().recommendations.status, RecommendationStatus.exhausted);
    expect(repository.cursors, [null, const ExternalRecommendationCursor(2)]);
  });

  test('append error keeps content and retry uses the exact failed cursor', () async {
    var fail = true;
    repository.respond = (cursor) async {
      if (cursor == null) {
        return RecommendationPage(
          items: [_item('first')],
          kind: RecommendationKind.discovery,
          nextCursor: const ExternalRecommendationCursor(2),
        );
      }
      if (fail) throw StateError('temporary');
      return RecommendationPage(items: [_item('second')], kind: RecommendationKind.discovery);
    };
    await load();
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    expect(getState().recommendations.items.map((item) => item.id), ['first']);
    expect(getState().recommendations.status, RecommendationStatus.failure);
    fail = false;
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    expect(getState().recommendations.items.map((item) => item.id), ['first', 'second']);
    expect(getState().recommendations.status, RecommendationStatus.exhausted);
    expect(repository.cursors, [null, const ExternalRecommendationCursor(2), const ExternalRecommendationCursor(2)]);
    expect(() => getState().recommendations.items.add(_item('mutation')), throwsUnsupportedError);
  });

  test('initial failure retries and concurrent load requests are coalesced', () async {
    final gate = Completer<RecommendationPage>();
    repository.respond = (_) => gate.future;
    await load();
    bloc.add(const LoadRecommendations());
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    expect(getState().recommendations.status, RecommendationStatus.loading);
    expect(repository.cursors, [null]);
    gate.completeError(StateError('offline'));
    await pumpEventQueue();
    expect(getState().recommendations.status, RecommendationStatus.failure);
    repository.respond = (_) async => RecommendationPage(items: [_item('retry')], kind: RecommendationKind.discovery);
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    expect(getState().recommendations.items.map((item) => item.id), ['retry']);
    await bloc.close();
    expect(repository.released, [repository.sessions.first]);
  });

  test('duplicate-only pages yield after four requests and continue from the next raw cursor', () async {
    repository.respond = (cursor) async => RecommendationPage(
      items: [_item('current')],
      kind: RecommendationKind.discovery,
      nextCursor: ExternalRecommendationCursor(cursor == null ? 2 : (cursor as ExternalRecommendationCursor).page + 1),
    );
    await load();
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    expect(repository.cursors, hasLength(4));
    expect(getState().recommendations.status, RecommendationStatus.ready);
    expect(getState().recommendations.items, isEmpty);
    expect(getState().recommendations.cursor, const ExternalRecommendationCursor(5));
    bloc.add(const LoadRecommendations());
    await pumpEventQueue();
    expect(repository.cursors, hasLength(8));
    expect(repository.cursors[4], const ExternalRecommendationCursor(5));
  });

  test('a queued load cannot allocate another recommendation visit after close releases it', () async {
    repository.respond = (_) async => RecommendationPage(items: [_item('never')], kind: RecommendationKind.discovery);
    await load();
    bloc.add(const LoadRecommendations());
    await bloc.close();
    expect(repository.released, hasLength(1));
    expect(repository.cursors, isEmpty);
    expect(repository.sessions, isEmpty);
    expect(getState().recommendations.status, RecommendationStatus.initial);
  });

  group('related recommendations follow the wallpaper, however it was opened', () {
    late _Firestore firestore;
    late _Prism prism;
    late WallpaperDetailBloc detail;

    setUp(() {
      firestore = _Firestore();
      prism = _Prism();
      final views = _Views();
      final palette = _Palette();
      final count = _Count();
      final blocks = _Blocks();
      when(() => views.call(any())).thenAnswer((_) async => Result.error(const UnknownFailure('offline')));
      when(() => count.call(any())).thenAnswer((_) async => Result.error(const UnknownFailure('offline')));
      when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const UnknownFailure('none')));
      when(() => blocks.getBlockedCreatorEmails(waitForInitialLoad: true)).thenAnswer((_) async => <String>{});
      detail = WallpaperDetailBloc(
        prism,
        _Wallhaven(),
        _Pexels(),
        views,
        palette,
        count,
        null,
        WallpaperRecommendationRepositoryImpl(
          firestore: () => firestore,
          wallhaven: _Wallhaven.new,
          pexels: _Pexels.new,
          settings: () => SettingsLocalDataSource(InMemoryLocalStore()),
          blocks: () => blocks,
          localSearch: (_) async => const <FeedItemEntity>[],
        ),
      );
    });
    tearDown(() => detail.close());

    Future<WallpaperDetailLoaded> recommend(WallpaperDetailEvent open) async {
      detail.add(open);
      await pumpEventQueue();
      detail.add(const LoadRecommendations());
      await pumpEventQueue();
      return detail.state as WallpaperDetailLoaded;
    }

    PrismWallpaper wall(String id, String category) => PrismWallpaper(
      core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', category: category),
    );

    test('a bundled starter gets more of its own category', () async {
      final starter = PrismFeedItem(id: 'starter-sunset', wallpaper: wall('starter-sunset', 'Nature'));
      expect(BundledWallpapers.isStarter(starter), isTrue);
      firestore.rows = [
        {'id': 'meadow', 'category': 'Nature', 'review': true},
      ];

      final state = await recommend(LoadFromEntity(entity: starter));

      expect(state.recommendations.kind, RecommendationKind.related);
      expect(state.recommendations.items.map((item) => item.id), ['meadow']);
      expect(firestore.specs.single.filters.map((filter) => (filter.field, filter.value)), [
        ('category', 'Nature'),
        ('review', true),
      ]);
    });

    test('a downloaded catalogue wallpaper reopened from its file gets more of its own category', () async {
      when(() => prism.fetchCanonicalById('wall')).thenAnswer((_) async => Result.success(wall('wall', 'Abstract')));
      firestore.rows = [
        {'id': 'shapes', 'category': 'Abstract', 'review': true},
      ];

      final state = await recommend(
        const LoadFromId(wallId: 'wall', source: WallpaperSource.prism, localFilePath: '/downloads/wall.jpg'),
      );

      expect(state.entity.id, 'wall');
      expect(state.recommendations.kind, RecommendationKind.related);
      expect(state.recommendations.items.map((item) => item.id), ['shapes']);
      expect(firestore.specs.single.filters.map((filter) => (filter.field, filter.value)), [
        ('category', 'Abstract'),
        ('review', true),
      ]);
    });
  });
}
