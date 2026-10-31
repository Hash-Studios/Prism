import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CreatorDirectoryRepository)
class CreatorDirectoryRepositoryImpl implements CreatorDirectoryRepository {
  CreatorDirectoryRepositoryImpl(this._firestore, this._blocks) : _call = _callable;

  @visibleForTesting
  CreatorDirectoryRepositoryImpl.withCaller(this._firestore, this._blocks, this._call);

  static const String _collection = 'creatorDirectory';
  static const int _inLimit = 30;

  final FirestoreClient _firestore;
  final UserBlockRepository _blocks;
  final Future<Object?> Function(String name, Map<String, Object?> data) _call;
  final Map<String, Future<FollowedBy>> _followedBy = <String, Future<FollowedBy>>{};

  static Future<Object?> _callable(String name, Map<String, Object?> data) async =>
      (await appFunctions.httpsCallable(name).call<Object?>(data)).data;

  String get _viewer => app_state.prismUser.id;

  @override
  Future<CreatorPage> fetchPage({
    String? category,
    int? afterRank,
    int limit = CreatorDirectoryRepository.pageSize,
  }) async {
    final List<CreatorDirectoryEntry> entries = await _firestore.query<CreatorDirectoryEntry>(
      FirestoreQuerySpec(
        collection: _collection,
        sourceTag: 'creator_directory.page',
        filters: <FirestoreFilter>[
          if (category != null)
            FirestoreFilter(field: 'categories', op: FirestoreFilterOp.arrayContains, value: category),
        ],
        orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'rank')],
        startAfterFieldValues: afterRank == null ? null : <Object?>[afterRank],
        limit: limit,
        cachePolicy: FirestoreCachePolicy.staleWhileRevalidate,
        dedupeWindowMs: 30000,
      ),
      (data, docId) => CreatorDirectoryEntry.fromMap(data, docId),
    );
    return CreatorPage(
      creators: await _withWalls(await _visible(entries)),
      nextRank: entries.length < limit ? null : entries.last.rank,
    );
  }

  @override
  Future<Set<String>> followedAmong(List<String> uids) async {
    final String viewer = _viewer;
    if (viewer.isEmpty || uids.isEmpty) return <String>{};
    final Set<String> followed = <String>{};
    for (int i = 0; i < uids.length; i += _inLimit) {
      final List<String> chunk = uids.sublist(i, (i + _inLimit).clamp(0, uids.length));
      followed.addAll(
        await _firestore.query<String>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.profileFollowing(viewer),
            sourceTag: 'creator_directory.followed_among',
            filters: <FirestoreFilter>[
              FirestoreFilter(field: 'targetUid', op: FirestoreFilterOp.whereIn, value: chunk),
            ],
          ),
          (_, docId) => docId,
        ),
      );
    }
    return followed;
  }

  @override
  Future<List<DirectoryCreator>> similarTo(String uid, {int limit = 6}) async {
    final CreatorDirectoryEntry? source = await _firestore.getById<CreatorDirectoryEntry>(
      _collection,
      uid,
      (data, docId) => CreatorDirectoryEntry.fromMap(data, docId),
      sourceTag: 'creator_directory.similar_source',
    );
    final List<String> ids = source?.similar.where((id) => id != uid).toList(growable: false) ?? const <String>[];
    if (ids.isEmpty) return const <DirectoryCreator>[];
    final List<CreatorDirectoryEntry> entries = <CreatorDirectoryEntry>[];
    for (int i = 0; i < ids.length; i += _inLimit) {
      entries.addAll(
        await _firestore.query<CreatorDirectoryEntry>(
          FirestoreQuerySpec(
            collection: _collection,
            sourceTag: 'creator_directory.similar',
            filters: <FirestoreFilter>[
              FirestoreFilter(
                field: 'uid',
                op: FirestoreFilterOp.whereIn,
                value: ids.sublist(i, (i + _inLimit).clamp(0, ids.length)),
              ),
            ],
          ),
          (data, docId) => CreatorDirectoryEntry.fromMap(data, docId),
        ),
      );
    }
    final Map<String, CreatorDirectoryEntry> byId = <String, CreatorDirectoryEntry>{for (final e in entries) e.uid: e};
    final List<CreatorDirectoryEntry> visible = await _visible(<CreatorDirectoryEntry>[
      for (final String id in ids)
        if (byId[id] case final CreatorDirectoryEntry e) e,
    ]);
    final Set<String> followed = await followedAmong(visible.map((e) => e.uid).toList(growable: false));
    return _withWalls(visible.where((e) => !followed.contains(e.uid)).take(limit).toList(growable: false));
  }

  @override
  Future<FollowedBy> followedBy(String creatorUid) {
    final String key = '$_viewer::$creatorUid';
    return _followedBy[key] ??= _loadFollowedBy(creatorUid).catchError((Object error) {
      _followedBy.remove(key);
      throw error;
    });
  }

  Future<FollowedBy> _loadFollowedBy(String creatorUid) async {
    final Object? raw = await _call('getFollowedBy', <String, Object?>{'creatorUid': creatorUid});
    if (raw is! Map) return FollowedBy.none;
    final Object? count = raw['count'];
    final Object? people = raw['people'];
    return FollowedBy(
      count: count is num ? count.toInt() : 0,
      people: people is List
          ? <FollowedByPerson>[
              for (final Object? p in people)
                if (p is Map && p['name'] is String && (p['name']! as String).isNotEmpty)
                  (name: p['name']! as String, photoUrl: p['photo'] is String ? p['photo']! as String : ''),
            ]
          : const <FollowedByPerson>[],
    );
  }

  Future<List<CreatorDirectoryEntry>> _visible(List<CreatorDirectoryEntry> entries) async {
    final BlockedCreators blocked = await _blocks.loadBlockedCreators();
    final String viewer = _viewer;
    return entries
        .where((e) => e.uid != viewer && !BlockedCreatorsFilter.hidesCreatorUid(e.uid, blocked))
        .toList(growable: false);
  }

  /// Loads every creator's top walls in as few queries as the `in` limit allows. A wall removed since the job ran is
  /// left out, and a creator with no walls left is dropped.
  Future<List<DirectoryCreator>> _withWalls(List<CreatorDirectoryEntry> entries) async {
    final List<String> ids = <String>{for (final e in entries) ...e.wallIds}.toList(growable: false);
    final Map<String, PrismWallpaper> walls = <String, PrismWallpaper>{};
    for (int i = 0; i < ids.length; i += _inLimit) {
      final rows = await _firestore.query<({String docId, PrismWallDocDto doc})>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'creator_directory.walls',
          filters: <FirestoreFilter>[
            FirestoreFilter(
              field: 'id',
              op: FirestoreFilterOp.whereIn,
              value: ids.sublist(i, (i + _inLimit).clamp(0, ids.length)),
            ),
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          cachePolicy: FirestoreCachePolicy.memoryFirst,
        ),
        (data, docId) => (docId: docId, doc: PrismWallDocDto.fromJson(data)),
      );
      for (final row in rows) {
        final PrismWallpaper wall = row.doc.toDomain(docId: row.docId);
        walls[row.doc.id] = wall;
      }
    }
    return <DirectoryCreator>[
      for (final e in entries)
        if (<PrismWallpaper>[
              for (final String id in e.wallIds)
                if (walls[id] case final PrismWallpaper w) w,
            ]
            case final List<PrismWallpaper> own when own.isNotEmpty)
          DirectoryCreator(entry: e, walls: own),
    ];
  }
}
