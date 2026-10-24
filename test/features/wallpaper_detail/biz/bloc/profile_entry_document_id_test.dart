import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/fake_user_block_repository.dart';
import '../../../../support/profile_user_fixture.dart';

class _Prism extends Mock implements PrismWallpaperRepository {}

class _Wallhaven extends Mock implements WallhavenWallpaperRepository {}

class _Pexels extends Mock implements PexelsWallpaperRepository {}

class _Views extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _Palette extends Mock implements PaletteRepository {}

class _Count extends Mock implements GetWallpaperSetCountUseCase {}

/// Home and a creator profile open the same wall document. Both must reach the detail screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prism-profile-entry-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    app_state.prismUser = profileUser(id: 'viewer');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await directory.delete(recursive: true);
  });

  const String documentId = 'document-7';
  const String fullUrl = 'https://example.test/full.jpg';

  Future<FeedItemEntity> profileEntry(Map<String, dynamic> data) async {
    final client = FakeFirestoreClient(onQuery: (_) => <FakeDocRow>[(id: documentId, data: data)]);
    final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final result = await PublicProfileRepositoryImpl(client, blocks).fetchWalls(userId: 'creatorUid', refresh: true);
    return result.data!.items.single.toFeedItem();
  }

  Future<FeedItemEntity> restoredProfileEntry() async {
    final client = FakeFirestoreClient()..queryError = StateError('offline after restart');
    final blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    final result = await PublicProfileRepositoryImpl(client, blocks).fetchWalls(userId: 'creatorUid', refresh: true);
    return result.data!.items.single.toFeedItem();
  }

  late _Prism prism;

  Future<WallpaperDetailState> openDetail(FeedItemEntity entity, PrismWallpaper stored, {required bool hasRawId}) {
    prism = _Prism();
    when(() => prism.fetchCanonicalById(any())).thenAnswer(
      (invocation) async => Result.success<PrismWallpaper?>(
        hasRawId && invocation.positionalArguments.single == stored.id ? stored : null,
      ),
    );
    when(() => prism.fetchCanonicalByDocumentId(documentId)).thenAnswer((_) async => Result.success(stored));
    final views = _Views();
    when(() => views(any())).thenAnswer((_) async => Result.success('0'));
    final palette = _Palette();
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('none')));
    final count = _Count();
    when(() => count(any())).thenAnswer((_) async => Result.success<int?>(null));
    final bloc = WallpaperDetailBloc(
      prism,
      _Wallhaven(),
      _Pexels(),
      views,
      palette,
      count,
      OfflineWallpaperCatalog(store: DurableJsonStore('catalog', directory: directory)),
    );
    addTearDown(bloc.close);
    bloc.add(LoadFromEntity(entity: entity));
    return bloc.stream
        .firstWhere((state) => state is WallpaperDetailError || state is WallpaperDetailLoaded)
        .timeout(const Duration(seconds: 5));
  }

  for (final String rawId in <String>['WALL7', '']) {
    final String label = rawId.isEmpty ? 'without a raw id' : 'with raw id $rawId';

    test('a wall $label opens from Home and from the creator profile', () async {
      final Map<String, dynamic> data = <String, dynamic>{
        if (rawId.isNotEmpty) 'id': rawId,
        'wallpaper_url': fullUrl,
        'wallpaper_thumb': 'https://example.test/thumb.jpg',
        'email': 'creator@prism.test',
        'review': true,
      };
      final PrismWallpaper stored = PrismWallDocDto.fromJson(data).toDomain(docId: documentId);
      final FeedItemEntity home = PrismFeedItem(id: stored.id, wallpaper: stored);
      final FeedItemEntity profile = await profileEntry(data);

      expect(profile.id, home.id);
      for (final FeedItemEntity entry in <FeedItemEntity>[home, profile]) {
        final WallpaperDetailState state = await openDetail(entry, stored, hasRawId: rawId.isNotEmpty);
        expect(state, isA<WallpaperDetailLoaded>(), reason: identical(entry, home) ? 'Home' : 'profile');
        expect((state as WallpaperDetailLoaded).entity.fullUrl, fullUrl);
      }
    });
  }

  Map<String, dynamic> wallData(String rawId) => <String, dynamic>{
    if (rawId.isNotEmpty) 'id': rawId,
    'wallpaper_url': fullUrl,
    'wallpaper_thumb': 'https://example.test/thumb.jpg',
    'email': 'creator@prism.test',
    'review': true,
  };

  for (final String rawId in <String>['WALL7', '']) {
    final String label = rawId.isEmpty ? 'without a raw id' : 'with raw id $rawId';

    test('a wall $label still opens from the creator profile after a restart restores it from the cache', () async {
      final Map<String, dynamic> data = wallData(rawId);
      final PrismWallpaper stored = PrismWallDocDto.fromJson(data).toDomain(docId: documentId);
      await profileEntry(data);

      final FeedItemEntity restored = await restoredProfileEntry();

      expect(restored.id, stored.id);
      final WallpaperDetailState state = await openDetail(restored, stored, hasRawId: rawId.isNotEmpty);
      expect(state, isA<WallpaperDetailLoaded>());
      expect((state as WallpaperDetailLoaded).entity.fullUrl, fullUrl);
    });
  }

  test('a restored wall with its own raw id does not fall back to its document id', () async {
    final Map<String, dynamic> data = wallData('WALL7');
    final PrismWallpaper stored = PrismWallDocDto.fromJson(data).toDomain(docId: documentId);
    await profileEntry(data);

    final FeedItemEntity restored = await restoredProfileEntry();
    final WallpaperDetailState state = await openDetail(restored, stored, hasRawId: false);

    expect(state, isA<WallpaperDetailError>());
    verifyNever(() => prism.fetchCanonicalByDocumentId(any()));
  });

  test('a wall from a cache written before document ids were stored still restores and opens by its id', () async {
    final Map<String, dynamic> data = wallData('');
    final PrismWallpaper stored = PrismWallDocDto.fromJson(data).toDomain(docId: documentId);
    await DurableJsonStore('public_profiles').write('v2::viewer::walls:creatorUid', <String, Object?>{
      'itemsJson': jsonEncode(<Object?>[
        <String, dynamic>{...data, 'id': documentId},
      ]),
      'hasMore': false,
    });

    final FeedItemEntity restored = await restoredProfileEntry();

    expect(restored.id, documentId);
    expect((restored as PrismFeedItem).wallpaper.firestoreDocumentId, isNull);
    final WallpaperDetailState state = await openDetail(restored, stored, hasRawId: true);
    expect(state, isA<WallpaperDetailLoaded>());
    verifyNever(() => prism.fetchCanonicalByDocumentId(any()));
  });
}
