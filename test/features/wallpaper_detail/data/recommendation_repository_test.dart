import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/feed_cache/pagination_session.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_wall_tiles.dart';
import 'package:Prism/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/data/repositories/wallpaper_recommendation_repository_impl.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_feed_cache_local_data_source.dart';
import '../../../support/in_memory_local_store.dart';

class _Firestore extends Fake implements FirestoreClient {
  final specs = <FirestoreQuerySpec>[];
  final getErrors = <String, Object>{};
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> get rows => _rows;
  set rows(List<Map<String, dynamic>> value) {
    // Existing fixtures describe newest-first dated documents. Explicit nulls stay null;
    // missing-field cases remove the field after assigning the fixture.
    _rows = [
      for (var i = 0; i < value.length; i++) {'createdAt': Timestamp(1800000000 - i, 0), ...value[i]},
    ];
  }

  bool fail = false;
  Completer<void>? queryEntered;
  Completer<void>? queryGate;

  Map<String, dynamic>? _document(String id) {
    if (fail) throw StateError('offline');
    if (getErrors.containsKey(id)) throw getErrors[id]!;
    final index = rows.indexWhere((row) => 'doc-${row['id']}' == id);
    return index < 0 ? null : rows[index];
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    final data = _document(id);
    return data == null ? null : map(data, id);
  }

  int _compare(Object? left, Object? right) {
    if (left == right) return 0;
    if (left == null) return -1;
    if (right == null) return 1;
    if (left is Timestamp && right is Timestamp) {
      final seconds = left.seconds.compareTo(right.seconds);
      return seconds == 0 ? left.nanoseconds.compareTo(right.nanoseconds) : seconds;
    }
    if (left is Timestamp && right is String) return -1;
    if (left is String && right is Timestamp) return 1;
    if (left is String && right is String) return left.compareTo(right);
    throw StateError('Unsupported fake Firestore comparison: $left, $right');
  }

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    specs.add(spec);
    queryEntered?.complete();
    await queryGate?.future;
    if (fail) throw StateError('offline');
    final orders = [
      ...spec.orderBy,
      if (!spec.orderBy.any((order) => order.field == firestoreDocumentIdField))
        FirestoreOrderBy(field: firestoreDocumentIdField, descending: spec.orderBy.lastOrNull?.descending ?? false),
    ];
    Object? field(Map<String, dynamic> row, String name) =>
        name == firestoreDocumentIdField ? 'doc-${row['id']}' : row[name];
    int compare(Map<String, dynamic> row, List<Object?> values) {
      for (var i = 0; i < values.length; i++) {
        final result = _compare(field(row, orders[i].field), values[i]);
        if (result != 0) return orders[i].descending ? -result : result;
      }
      return 0;
    }

    List<Object?>? after = spec.startAfterFieldValues;
    if (spec.startAfterDocId case final String id) {
      final document = _document(id);
      if (document != null) {
        if (spec.orderBy.any(
          (order) => order.field != firestoreDocumentIdField && !document.containsKey(order.field),
        )) {
          throw StateError('Cursor document is missing an ordered field');
        }
        after = orders.map((order) => field(document, order.field)).toList();
      }
    }
    final ordered = rows
        .where(
          (row) => spec.orderBy.every(
            (order) => order.field == firestoreDocumentIdField || row.containsKey(order.field),
          ),
        )
        .where((row) => spec.filters.every((filter) => row[filter.field] == filter.value))
        .toList()
      ..sort((left, right) => compare(left, orders.map((order) => field(right, order.field)).toList()));
    return ordered
        .where((row) => after == null || compare(row, after) > 0)
        .take(spec.limit ?? rows.length)
        .map((row) => map(row, 'doc-${row['id']}'))
        .toList();
  }
}

class _Wallhaven extends Mock implements WallhavenWallpaperRepository, PaginationSession {}

class _Pexels extends Mock implements PexelsWallpaperRepository, PaginationSession {}

class _Blocks extends Mock implements UserBlockRepository {}

FeedItemEntity _item(
  String id, {
  WallpaperSource source = WallpaperSource.prism,
  List<String>? tags,
  String category = 'Nature',
  String? documentId,
  bool undated = false,
}) {
  final core = WallpaperCore(
    id: id,
    source: source,
    fullUrl: '',
    thumbnailUrl: '',
    category: category,
    createdAt: undated ? null : DateTime.utc(2026),
  );
  return switch (source) {
    WallpaperSource.prism => PrismFeedItem(
      id: id,
      wallpaper: PrismWallpaper(core: core, tags: tags, firestoreDocumentId: documentId),
    ),
    WallpaperSource.wallhaven => WallhavenFeedItem(
      id: id,
      wallpaper: WallhavenWallpaper(core: core, tags: tags),
    ),
    _ => PexelsFeedItem(
      id: id,
      wallpaper: PexelsWallpaper(core: core),
    ),
  };
}

PrismFeedItem _dropItem(String documentId) => dropWallFeedItem(
  DropWall(id: documentId, title: '', thumb: '', resolution: '', by: '', seriesId: ''),
  DropUnlock(wallId: documentId, weekKey: '2026-W46', url: 'https://example.test/unlocked.jpg'),
);

void main() {
  late _Firestore firestore;
  late _Wallhaven wallhaven;
  late _Pexels pexels;
  late WallpaperRecommendationRepositoryImpl repository;
  late _Blocks blocks;
  late SettingsLocalDataSource settings;
  List<FeedItemEntity> local = [];
  setUp(() {
    firestore = _Firestore();
    wallhaven = _Wallhaven();
    pexels = _Pexels();
    blocks = _Blocks();
    when(() => blocks.loadBlockedCreators()).thenAnswer((_) async => KnownBlockedCreators({'blocked-uid'}));
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    local = [];
    repository = WallpaperRecommendationRepositoryImpl(
      firestore: () => firestore,
      wallhaven: () => wallhaven,
      pexels: () => pexels,
      settings: () => settings,
      blocks: () => blocks,
      localSearch: (_) async => local,
    );
  });

  test('raw last Firestore document advances past blocked and anime rows', () async {
    firestore.rows = [
      for (var i = 0; i < 24; i++)
        {
          'id': '$i',
          'category': 'Nature',
          'review': true,
          'creatorUid': i == 23 ? 'blocked-uid' : '',
          'tags': i == 22 ? ['anime'] : <String>[],
        },
    ];
    final page = await repository.load(current: _item('current'), sessionKey: 'a');
    expect(page.items.map((item) => item.id), [for (var i = 0; i < 22; i++) '$i']);
    expect(
      page.nextCursor,
      PrismRecommendationCursor('doc-23', visitedDocumentIds: {for (var i = 0; i < 24; i++) 'doc-$i'}),
    );
    firestore.rows = [
      {'id': 'next', 'category': 'Nature', 'review': true},
    ];
    final next = await repository.load(current: _item('current'), sessionKey: 'a', cursor: page.nextCursor);
    expect(next.items.map((item) => item.id), ['next']);
    expect(next.nextCursor, isNull);
    expect(firestore.specs.first.filters.map((filter) => (filter.field, filter.value)), [
      ('category', 'Nature'),
      ('review', true),
    ]);
  });

  test('each Prism wall gets its own neighbours, then the newer walls, and stops at itself', () async {
    firestore.rows = [
      for (var i = 0; i < 30; i++) {'id': 'w$i', 'category': 'Nature', 'review': true},
    ];
    Future<List<String>> visit(String id) async {
      final ids = <String>[];
      RecommendationCursor? cursor;
      do {
        final page = await repository.load(
          current: _item(id, documentId: 'doc-$id'),
          sessionKey: id,
          cursor: cursor,
        );
        ids.addAll(page.items.map((item) => item.id));
        cursor = page.nextCursor;
      } while (cursor != null);
      return ids;
    }

    expect(await visit('w10'), [for (var i = 11; i < 30; i++) 'w$i', for (var i = 0; i < 10; i++) 'w$i']);
    expect((await visit('w20')).take(3), ['w21', 'w22', 'w23']);
  });

  for (final anchor in ['doc-missing', 'doc-w10']) {
    test('missing or recategorised anchor $anchor does not repeat walls on wrap', () async {
      firestore.rows = [
        for (var i = 0; i < 30; i++) {'id': 'w$i', 'category': i == 10 ? 'Other' : 'Nature', 'review': true},
      ];
      final ids = <String>[];
      RecommendationCursor? cursor;
      var calls = 0;
      do {
        final page = await repository.load(
          current: _item('current', documentId: anchor),
          sessionKey: anchor,
          cursor: cursor,
        );
        ids.addAll(page.items.map((item) => item.id));
        cursor = page.nextCursor;
        expect(++calls, lessThan(6));
      } while (cursor != null);
      expect(ids.toSet(), {
        for (var i = 0; i < 30; i++)
          if (i != 10) 'w$i',
      });
      expect(ids, hasLength(29));
    });
  }

  test('deleting the open wall and first returned wall mid-visit still stops before duplicates', () async {
    firestore.rows = [
      for (var i = 0; i < 60; i++) {'id': 'w$i', 'category': 'Nature', 'review': true},
    ];
    final current = _item('w10', documentId: 'doc-w10');
    final first = await repository.load(current: current, sessionKey: 'deleted-anchor');
    firestore.rows.removeWhere((row) => ['w10', 'w11'].contains(row['id']));
    final ids = first.items.map((item) => item.id).toList();
    var cursor = first.nextCursor;
    var calls = 0;
    do {
      final page = await repository.load(current: current, sessionKey: 'deleted-anchor', cursor: cursor);
      ids.addAll(page.items.map((item) => item.id));
      cursor = page.nextCursor;
      expect(++calls, lessThan(6));
    } while (cursor != null);
    expect(ids, [for (var i = 11; i < 60; i++) 'w$i', for (var i = 0; i < 10; i++) 'w$i']);
  });

  test('deleted later cursor cannot restart the same full page forever', () async {
    firestore.rows = [
      for (var i = 0; i < 50; i++) {'id': 'w$i', 'category': 'Nature', 'review': true},
    ];
    final current = _item('current', documentId: 'doc-missing');
    final first = await repository.load(current: current, sessionKey: 'deleted-cursor');
    firestore.rows.removeAt(23);
    final next = await repository.load(current: current, sessionKey: 'deleted-cursor', cursor: first.nextCursor);
    expect(first.items.first.id, 'w0');
    expect(next.items, isEmpty);
    expect(next.nextCursor, isNull);
  });

  for (final undated in [false, true]) {
    test('a missing stored createdAt starts newest whether the domain date is null: $undated', () async {
      firestore.rows = [
        for (var i = 0; i < 5; i++) {'id': 'w$i', 'category': 'Nature', 'review': true},
      ];
      firestore.rows[2].remove('createdAt');
      final page = await repository.load(
        current: _item('w2', documentId: 'doc-w2', undated: undated),
        sessionKey: 'missing-date-$undated',
      );
      expect(firestore.specs.first.startAfterDocId, isNull);
      expect(firestore.specs.first.startAfterFieldValues, isNull);
      expect(page.items.map((item) => item.id), ['w0', 'w1', 'w3', 'w4']);
      expect(page.nextCursor, isNull);
    });
  }

  test('an unlocked released Drop keeps its own stored timestamp anchor despite an undated domain item', () async {
    firestore.rows = [
      for (var i = 0; i < 5; i++) {'id': 'w$i', 'category': 'Nature', 'review': true},
    ];
    final current = _dropItem('doc-w2');
    expect(current.wallpaperCore.createdAt, isNull);
    final first = await repository.load(current: current, sessionKey: 'released-drop');
    expect(first.items.map((item) => item.id), ['w3', 'w4']);
    expect(
      first.nextCursor,
      const PrismRecommendationCursor(null, wrapped: true, visitedDocumentIds: {'doc-w3', 'doc-w4'}),
    );
    final wrapped = await repository.load(current: current, sessionKey: 'released-drop', cursor: first.nextCursor);
    expect(wrapped.items.map((item) => item.id), ['w0', 'w1']);
    expect(wrapped.nextCursor, isNull);
  });

  for (final rawDate in <Object?>[null, 'not-a-date']) {
    test('a stored $rawDate createdAt remains a valid anchor even when the DTO date is null', () async {
      firestore.rows = [
        for (final id in ['c', 'b', 'a']) {'id': id, 'category': 'Nature', 'review': true, 'createdAt': rawDate},
      ];
      final wall = PrismWallDocDto.fromJson(firestore.rows[1]).toDomain(docId: 'doc-b');
      final current = PrismFeedItem(id: wall.id, wallpaper: wall);
      expect(current.wallpaperCore.createdAt, isNull);
      final first = await repository.load(current: current, sessionKey: 'raw-anchor-$rawDate');
      expect(first.items.map((item) => item.id), ['a']);
      final wrapped = await repository.load(
        current: current,
        sessionKey: 'raw-anchor-$rawDate',
        cursor: first.nextCursor,
      );
      expect(wrapped.items.map((item) => item.id), ['c']);
      expect(wrapped.nextCursor, isNull);
    });
  }

  test('removing createdAt from a later cursor stops safely without duplicating a full page', () async {
    firestore.rows = [
      for (var i = 0; i < 50; i++) {'id': 'w$i', 'category': 'Nature', 'review': true},
    ];
    final current = _item('current');
    final first = await repository.load(current: current, sessionKey: 'removed-cursor-field');
    expect(first.items.map((item) => item.id), [for (var i = 0; i < 24; i++) 'w$i']);
    firestore.rows[23].remove('createdAt');
    final next = await repository.load(current: current, sessionKey: 'removed-cursor-field', cursor: first.nextCursor);
    expect(next.items, isEmpty);
    expect(next.nextCursor, isNull);
  });

  for (final rawDate in <Object?>[null, 'not-a-date']) {
    test('a later cursor with stored $rawDate createdAt advances by raw value and document ID', () async {
      firestore.rows = [
        for (var i = 29; i >= 0; i--)
          {'id': 'w${i.toString().padLeft(2, '0')}', 'category': 'Nature', 'review': true, 'createdAt': rawDate},
      ];
      final current = _item('current');
      final first = await repository.load(current: current, sessionKey: 'raw-cursor-$rawDate');
      final next = await repository.load(current: current, sessionKey: 'raw-cursor-$rawDate', cursor: first.nextCursor);
      expect([...first.items, ...next.items].map((item) => item.id), [
        for (var i = 29; i >= 0; i--) 'w${i.toString().padLeft(2, '0')}',
      ]);
      expect(next.items, hasLength(6));
      expect(next.nextCursor, isNull);
      expect(firestore.specs.last.startAfterFieldValues, [rawDate, 'doc-w06']);
    });
  }

  test('timestamp cursor preserves nanoseconds and descending document ID ties', () async {
    final timestamp = Timestamp(1800000000, 987654321);
    firestore.rows = [
      for (var i = 0; i < 26; i++)
        {
          'id': 'w${i.toString().padLeft(2, '0')}',
          'category': 'Nature',
          'review': true,
          'createdAt': timestamp,
        },
      {'id': 'older', 'category': 'Nature', 'review': true, 'createdAt': Timestamp(timestamp.seconds, 987654320)},
    ];
    final current = _item('current');
    final first = await repository.load(current: current, sessionKey: 'precision');
    final next = await repository.load(current: current, sessionKey: 'precision', cursor: first.nextCursor);
    expect(first.items.map((item) => item.id), [for (var i = 25; i >= 2; i--) 'w${i.toString().padLeft(2, '0')}']);
    expect(next.items.map((item) => item.id), ['w01', 'w00', 'older']);
    expect(next.nextCursor, isNull);
    expect(firestore.specs.last.startAfterFieldValues, [timestamp, 'doc-w02']);
    expect(firestore.specs.last.orderBy.map((order) => (order.field, order.descending)), [
      ('createdAt', true),
      (firestoreDocumentIdField, true),
    ]);
  });

  test('an unreadable active Drop discovers public newest walls without using a denied anchor', () async {
    firestore.rows = [
      {'id': 'newest', 'review': true},
      {'id': 'private', 'review': false},
      {'id': 'older', 'review': true},
    ];
    firestore.getErrors['doc-private'] = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    final page = await repository.load(current: _dropItem('doc-private'), sessionKey: 'private-drop');
    expect(page.items.map((item) => item.id), ['newest', 'older']);
    expect(page.kind, RecommendationKind.discovery);
    expect(page.nextCursor, isNull);
  });

  test('a failed Drop anchor lookup remains retryable instead of silently changing the neighbours', () async {
    firestore.rows = [
      for (var i = 0; i < 5; i++) {'id': 'w$i', 'review': true},
    ];
    final current = _dropItem('doc-w2');
    firestore.getErrors['doc-w2'] = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    await expectLater(repository.load(current: current, sessionKey: 'drop-network'), throwsA(isA<FirebaseException>()));
    firestore.getErrors.clear();
    final page = await repository.load(current: current, sessionKey: 'drop-network');
    expect(page.items.map((item) => item.id), ['w3', 'w4']);
    expect(page.kind, RecommendationKind.discovery);
  });

  test('empty document IDs use finite unanchored discovery and retries keep the same page', () async {
    firestore.rows = [
      for (var i = 0; i < 30; i++) {'id': 'w$i', 'category': 'Nature', 'review': true},
    ];
    final current = _item('current', documentId: '', category: '');
    final first = await repository.load(current: current, sessionKey: 'empty-id');
    final next = await repository.load(current: current, sessionKey: 'empty-id', cursor: first.nextCursor);
    final retry = await repository.load(current: current, sessionKey: 'empty-id', cursor: first.nextCursor);
    expect(first.kind, RecommendationKind.discovery);
    expect([...first.items, ...next.items].map((item) => item.id), [for (var i = 0; i < 30; i++) 'w$i']);
    expect(next.nextCursor, isNull);
    expect(retry.items.map((item) => item.id), [for (var i = 24; i < 30; i++) 'w$i']);
    expect(retry.nextCursor, isNull);
    expect(firestore.specs.first.startAfterDocId, isNull);
  });

  test('AI recommendations hide walls with metadata even when the legacy flag is absent', () async {
    await AiContentFilter.setShowsAi(settings, false);
    firestore.rows = [
      {
        'id': 'metadata-ai',
        'category': 'Nature',
        'review': true,
        'aiMetadata': {'prompt': 'a fox'},
      },
      {'id': 'flag-ai', 'category': 'Nature', 'review': true, 'isAiGenerated': true},
      {'id': 'human', 'category': 'Nature', 'review': true},
    ];

    final RecommendationPage page = await repository.load(current: _item('current'), sessionKey: 'ai-filter');

    expect(page.items.map((item) => item.id), ['human']);
    expect(page.nextCursor, isNull);
  });

  test('AI setting is applied when an in-flight recommendation query completes', () async {
    await AiContentFilter.setShowsAi(settings, true);
    firestore.rows = [
      {
        'id': 'metadata-ai',
        'category': 'Nature',
        'review': true,
        'aiMetadata': {'prompt': 'a fox'},
      },
      {'id': 'human', 'category': 'Nature', 'review': true},
    ];
    firestore.queryEntered = Completer<void>();
    firestore.queryGate = Completer<void>();

    final pendingPage = repository.load(current: _item('current'), sessionKey: 'ai-toggle-race');
    await firestore.queryEntered!.future;
    await AiContentFilter.setShowsAi(settings, false);
    firestore.queryGate!.complete();

    final page = await pendingPage;
    expect(page.items.map((item) => item.id), ['human']);
  });

  test('an unknown block list drops Prism rows with a creator and keeps Wallhaven discovery', () async {
    when(() => blocks.loadBlockedCreators()).thenAnswer((_) async => const UnknownBlockedCreators());
    firestore.rows = [
      {'id': 'blocked', 'category': 'Nature', 'review': true, 'creatorUid': 'blocked-uid'},
      {'id': 'kept', 'category': 'Nature', 'review': true, 'creatorUid': ''},
    ];
    final page = await repository.load(current: _item('current'), sessionKey: 'a');
    expect(page.items.map((item) => item.id), ['kept']);

    when(
      () => wallhaven.fetchFeed(
        categoryName: 'space',
        refresh: any(named: 'refresh'),
        paginationKey: any(named: 'paginationKey'),
        startPage: any(named: 'startPage'),
        categories: 100,
        purity: 100,
      ),
    ).thenAnswer(
      (_) async => Result.success([(_item('found', source: WallpaperSource.wallhaven) as WallhavenFeedItem).wallpaper]),
    );
    when(() => wallhaven.hasMoreForCategory('space', paginationKey: any(named: 'paginationKey'))).thenReturn(true);
    final wallhavenPage = await repository.load(
      current: _item('current', source: WallpaperSource.wallhaven, tags: [' space ', 'SPACE']),
      sessionKey: 'visit-wh',
    );
    expect(wallhavenPage.items.map((item) => item.id), ['found']);
  });

  test('Wallhaven visits do not share each other or search cursors; release is scoped', () async {
    final keys = <String>[];
    final refreshes = <bool>[];
    when(
      () => wallhaven.fetchFeed(
        categoryName: 'space',
        refresh: any(named: 'refresh'),
        paginationKey: any(named: 'paginationKey'),
        startPage: any(named: 'startPage'),
        categories: 100,
        purity: 100,
      ),
    ).thenAnswer((call) async {
      keys.add(call.namedArguments[#paginationKey] as String);
      refreshes.add(call.namedArguments[#refresh] as bool);
      return Result.success([(_item('found', source: WallpaperSource.wallhaven) as WallhavenFeedItem).wallpaper]);
    });
    when(() => wallhaven.hasMoreForCategory('space', paginationKey: any(named: 'paginationKey'))).thenReturn(true);
    final current = _item('current', source: WallpaperSource.wallhaven, tags: [' space ', 'SPACE']);
    final page = await repository.load(current: current, sessionKey: 'visit-a');
    await repository.load(current: current, sessionKey: 'visit-b');
    final next = await repository.load(current: current, sessionKey: 'visit-a', cursor: page.nextCursor);
    expect(next.items.map((item) => item.id), ['found']);
    expect(keys, ['detail:visit-a:wallhaven', 'detail:visit-b:wallhaven', 'detail:visit-a:wallhaven']);
    expect(refreshes, [true, true, false]);
    repository.release('visit-a');
    verify(() => wallhaven.releasePaginationKey('detail:visit-a:wallhaven')).called(1);
    verifyNever(() => wallhaven.releasePaginationKey('detail:visit-b:wallhaven'));
  });

  test('Pexels is curated discovery, never invented similarity', () async {
    when(
      () => pexels.fetchFeed(categoryName: 'Curated', refresh: true, startPage: 1, paginationKey: 'detail:p:pexels'),
    ).thenAnswer(
      (_) async => Result.success([(_item('photo', source: WallpaperSource.pexels) as PexelsFeedItem).wallpaper]),
    );
    when(() => pexels.hasMoreForCategory('Curated', paginationKey: 'detail:p:pexels')).thenReturn(true);
    final page = await repository.load(
      current: _item('current', source: WallpaperSource.pexels),
      sessionKey: 'p',
    );
    expect(page.items.map((item) => item.id), ['photo']);
    expect(page.kind, RecommendationKind.discovery);
    expect(page.nextCursor, const ExternalRecommendationCursor(2, provider: RecommendationProvider.pexels));
  });

  test('initial network failure uses local discovery but append failure remains retryable', () async {
    firestore.fail = true;
    local = [_item('saved')];
    final page = await repository.load(current: _item('current'), sessionKey: 'a');
    expect(page.items.map((item) => item.id), ['saved']);
    expect(page.kind, RecommendationKind.offline);
    expect(page.nextCursor, isNull);
    await expectLater(
      repository.load(current: _item('current'), sessionKey: 'a', cursor: const PrismRecommendationCursor('last')),
      throwsStateError,
    );
    local = [];
    await expectLater(repository.load(current: _item('current'), sessionKey: 'b'), throwsStateError);
  });

  test('a wall without its own category gets discovery, never an invented match', () async {
    firestore.rows = [
      {'id': 'general', 'review': true},
    ];
    final page = await repository.load(
      current: _item('uncategorised', category: '  '),
      sessionKey: 'plain',
    );
    expect(page.kind, RecommendationKind.discovery);
    expect(page.items.map((item) => item.id), ['general']);
    expect(firestore.specs.single.filters.map((filter) => filter.field), ['review']);
  });

  test('Wallhaven enrichment cannot change the query halfway through a visit', () async {
    final queries = <String>[];
    when(
      () => wallhaven.fetchFeed(
        categoryName: any(named: 'categoryName'),
        refresh: any(named: 'refresh'),
        startPage: any(named: 'startPage'),
        paginationKey: any(named: 'paginationKey'),
        categories: 100,
        purity: 100,
      ),
    ).thenAnswer((call) async {
      queries.add(call.namedArguments[#categoryName] as String);
      return Result.success(const <WallhavenWallpaper>[]);
    });
    when(() => wallhaven.hasMoreForCategory(any(), paginationKey: any(named: 'paginationKey'))).thenReturn(true);
    final first = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven),
      sessionKey: 'visit',
    );
    final next = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven, tags: ['space']),
      sessionKey: 'visit',
      cursor: first.nextCursor,
    );
    expect(queries, ['', '']);
    expect(next.kind, RecommendationKind.discovery);
  });

  test('Wallhaven fallback continues Pexels page two without returning to Wallhaven', () async {
    var wallhavenCalls = 0;
    final pages = <int>[];
    when(
      () => wallhaven.fetchFeed(
        categoryName: '',
        refresh: true,
        paginationKey: 'detail:fallback:wallhaven',
        startPage: 1,
        categories: 100,
        purity: 100,
      ),
    ).thenAnswer((_) async {
      wallhavenCalls++;
      return Result.error(const ServerFailure('offline'));
    });
    when(
      () => pexels.fetchFeed(
        categoryName: 'Curated',
        refresh: any(named: 'refresh'),
        startPage: any(named: 'startPage'),
        paginationKey: 'detail:fallback:pexels',
      ),
    ).thenAnswer((call) async {
      final page = call.namedArguments[#startPage] as int;
      pages.add(page);
      return Result.success([(_item('photo-$page', source: WallpaperSource.pexels) as PexelsFeedItem).wallpaper]);
    });
    when(() => pexels.hasMoreForCategory('Curated', paginationKey: 'detail:fallback:pexels')).thenReturn(true);
    final first = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven),
      sessionKey: 'fallback',
    );
    final next = await repository.load(
      current: _item('wall', source: WallpaperSource.wallhaven, tags: ['new tag']),
      sessionKey: 'fallback',
      cursor: first.nextCursor,
    );
    expect(wallhavenCalls, 1);
    expect(pages, [1, 2]);
    expect(next.items.single.id, 'photo-2');
    expect(next.kind, RecommendationKind.discovery);
  });

  test('offline Wallhaven recommendations respect category flags, including anime', () async {
    firestore.fail = true;
    await settings.set('WHpurity', 111);
    local = [
      _item('general', source: WallpaperSource.wallhaven, category: 'general'),
      _item('anime', source: WallpaperSource.wallhaven, category: 'anime'),
      _item('people', source: WallpaperSource.wallhaven, category: 'people'),
      _item('tag-anime', source: WallpaperSource.wallhaven, tags: ['anime']),
    ];
    final page = await repository.load(current: _item('wall'), sessionKey: 'offline');
    expect(page.items.map((item) => item.id), ['general']);
    expect(page.kind, RecommendationKind.offline);
  });

  test('restricted purity excludes unverifiable offline Wallhaven but preserves other providers', () async {
    firestore.fail = true;
    local = [
      _item('cached-wallhaven', source: WallpaperSource.wallhaven, category: 'general'),
      _item('saved-prism'),
      _item('saved-pexels', source: WallpaperSource.pexels),
    ];
    await settings.set('WHpurity', 111);
    final unrestricted = await repository.load(current: _item('wall'), sessionKey: 'unrestricted');
    expect(unrestricted.items.map((item) => item.id), ['cached-wallhaven', 'saved-prism', 'saved-pexels']);
    for (final purity in [100, 110]) {
      await settings.set('WHpurity', purity);
      final restricted = await repository.load(current: _item('wall'), sessionKey: 'restricted-$purity');
      expect(restricted.items.map((item) => item.id), ['saved-prism', 'saved-pexels']);
      expect(restricted.kind, RecommendationKind.offline);
    }
    local = [local.first];
    await expectLater(repository.load(current: _item('wall'), sessionKey: 'only-unverifiable'), throwsStateError);
  });

  for (final source in [WallpaperSource.wallhaven, WallpaperSource.pexels]) {
    test('released $source visit cannot recreate real provider caches after delayed completion', () async {
      final wh = WallhavenWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
      final px = PexelsWallpaperRepositoryImpl(FakeFeedCacheLocalDataSource());
      final repo = WallpaperRecommendationRepositoryImpl(
        firestore: () => firestore,
        wallhaven: () => wh,
        pexels: () => px,
        blocks: () => blocks,
        settings: () => settings,
        localSearch: (_) async => throw StateError('released visits must not fall back'),
      );
      final started = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(
        () async {
          final pending = repo.load(
            current: _item('wall', source: source),
            sessionKey: 'late',
          );
          final failure = expectLater(pending, throwsStateError);
          await started.future;
          repo.release('late');
          expect(wh.activePaginationSessions, 0);
          expect(px.activePaginationSessions, 0);
          response.complete(
            http.Response(
              jsonEncode(
                source == WallpaperSource.wallhaven
                    ? {
                        'data': <Object?>[],
                        'meta': {'current_page': 1, 'last_page': 1},
                      }
                    : {'photos': <Object?>[], 'page': 1, 'per_page': 24},
              ),
              200,
            ),
          );
          await failure;
          expect(wh.activePaginationSessions, 0);
          expect(px.activePaginationSessions, 0);
          wh.hasMoreForCategory('', paginationKey: 'detail:late:wallhaven');
          px.hasMoreForCategory('Curated', paginationKey: 'detail:late:pexels');
          expect(wh.activePaginationSessions, 0, reason: 'cursor reads must not allocate a new cache');
          expect(px.activePaginationSessions, 0, reason: 'cursor reads must not allocate a new cache');
        },
        () => MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
    });
  }
}
