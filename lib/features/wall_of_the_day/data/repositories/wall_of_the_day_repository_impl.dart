import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/prism_preview.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_of_the_day/data/wotd_entity_mapper.dart';
import 'package:Prism/features/wall_of_the_day/data/wotd_firestore_pointer.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: WallOfTheDayRepository)
class WallOfTheDayRepositoryImpl implements WallOfTheDayRepository {
  WallOfTheDayRepositoryImpl(
    this._firestoreClient,
    this._prismWallpaperRepository,
    this._userBlockRepository, {
    FeedCacheLocalDataSource? feedCacheLocal,
  }) : _feedCacheLocal = feedCacheLocal ?? FeedCacheLocalDataSource();

  final FirestoreClient _firestoreClient;
  final PrismWallpaperRepository _prismWallpaperRepository;
  final UserBlockRepository _userBlockRepository;
  final FeedCacheLocalDataSource _feedCacheLocal;

  static const String _pastPicksCollection = 'past_picks';

  _CachedPick? _cached;

  static bool _isSameCalendarDayUtc(DateTime a, DateTime b) {
    final au = a.toUtc();
    final bu = b.toUtc();
    return au.year == bu.year && au.month == bu.month && au.day == bu.day;
  }

  @override
  Future<Result<WallOfTheDayEntity?>> fetchToday() async {
    final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
    try {
      final WallOfTheDayFirestorePointer? pointer = await _firestoreClient.getById<WallOfTheDayFirestorePointer>(
        FirebaseCollections.wallOfTheDay,
        'current',
        (data, _) => WallOfTheDayFirestorePointer.fromMap(data),
        // Refresh the pointer while retaining Firestore's offline cache fallback.
        sourceTag: 'wotd.fetchToday.pointer',
      );

      if (pointer == null || pointer.wallDocumentId.isEmpty) {
        await _invalidateToday();
        return Result.success(null);
      }

      final DateTime featuredUtc = pointer.featuredAt.toUtc();
      final cached = _cached;
      if (cached != null &&
          cached.wallDocumentId == pointer.wallDocumentId &&
          _isSameCalendarDayUtc(cached.featuredDayUtc, featuredUtc)) {
        // Re-check against the caller's blocked creators on every call (not just on
        // fetch) so a since-blocked creator's pick disappears instantly, without
        // waiting for the day-scoped cache to expire.
        return Result.success(_visibleForCaller(cached.entity, cached.authorEmail, blocked));
      }

      final wallResult = await _prismWallpaperRepository.fetchByDocumentId(pointer.wallDocumentId);
      return await wallResult.fold<Future<Result<WallOfTheDayEntity?>>>(
        onSuccess: (wallpaper) async {
          if (wallpaper == null || !hasPrismPreview(wallpaper) || wallpaper.review != true) {
            await _invalidateToday();
            return Result.success(null);
          }
          final WallOfTheDayEntity entity = wallOfTheDayEntityFromPrismWallpaper(wallpaper);
          _cached = _CachedPick(
            entity: entity,
            wallDocumentId: pointer.wallDocumentId,
            featuredDayUtc: featuredUtc,
            authorEmail: wallpaper.core.authorEmail,
          );
          await _rememberToday(featuredUtc, pointer.wallDocumentId, wallpaper);
          return Result.success(_visibleForCaller(entity, wallpaper.core.authorEmail, blocked));
        },
        onFailure: (failure) async {
          if (_isTransientFailure(failure)) {
            final WallOfTheDayEntity? local = await _readCachedToday(
              featuredUtc,
              blocked,
              wallDocumentId: pointer.wallDocumentId,
            );
            if (local != null) return Result.success(local);
          } else {
            await _invalidateToday();
          }
          return Result.error(failure);
        },
      );
    } catch (e) {
      final bool transient = _isTransientError(e);
      final WallOfTheDayEntity? local = transient ? await _readCachedToday(DateTime.now().toUtc(), blocked) : null;
      if (!transient) await _invalidateToday();
      return local == null
          ? Result.error(ServerFailure("Could not load today's wallpaper: $e", code: mapFirestoreError(e).code))
          : Result.success(local);
    }
  }

  @override
  Future<WallOfTheDayEntity?> readCachedToday() => _readCachedToday(DateTime.now().toUtc(), null);

  @override
  Future<Result<List<WotdPastPick>>> fetchRecent({int limit = 30}) async {
    bool blockSnapshotReady = false;
    try {
      await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
      blockSnapshotReady = true;
      final query = await _queryRecentRows(
        FirestoreQuerySpec(
          collection: _pastPicksCollection,
          sourceTag: 'wotd.past_picks',
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'date', descending: true)],
          limit: limit,
          dedupeWindowMs: 1000,
        ),
        (data, docId) => (docId: docId, data: data),
      );
      final rows = query.rows;
      if (!query.authoritative) {
        final List<WotdPastPick>? cached = await _readArchive();
        if (cached != null) return Result.success(_visiblePicks(cached));
        if (rows.isEmpty) {
          return Result.error(const ServerFailure("Couldn't load past picks. Check your connection and try again."));
        }
      }
      final List<Result<WotdPastPick?>> resolved = await Future.wait(rows.map(_resolvePick));
      final Failure? firstFailure = resolved.map((result) => result.failure).nonNulls.firstOrNull;
      if (!query.authoritative && firstFailure == null && resolved.every((result) => result.data == null)) {
        return Result.error(const ServerFailure("Couldn't load past picks. Check your connection and try again."));
      }
      if (firstFailure != null) {
        final List<Failure> failures = resolved.map((result) => result.failure).nonNulls.toList(growable: false);
        final List<WotdPastPick>? cached = await _readArchive();
        final List<WotdPastPick>? reconciled = cached == null ? null : _reconcileArchiveRows(rows, resolved, cached);
        if (query.authoritative && reconciled != null) await _writeArchive(reconciled);
        if (failures.every(_isTransientFailure)) {
          if (reconciled != null) {
            if (reconciled.isNotEmpty || resolved.any((result) => result.isSuccess && result.data != null)) {
              return Result.success(_visiblePicks(reconciled));
            }
          }
        } else if (reconciled != null &&
            reconciled.isNotEmpty &&
            !resolved.any((result) => result.isSuccess && result.data != null)) {
          return Result.success(_visiblePicks(reconciled));
        }
        if (resolved.every((result) => result.isFailure || result.data == null) &&
            resolved.any((result) => result.isFailure)) {
          return Result.error(firstFailure);
        }
      }
      final List<WotdPastPick> picks = resolved.map((result) => result.data).nonNulls.toList(growable: false);
      if (query.authoritative && firstFailure == null) await _writeArchive(picks);
      return Result.success(_visiblePicks(picks));
    } catch (error, stackTrace) {
      logger.e('[WallOfTheDayRepository] fetchRecent failed', error: error, stackTrace: stackTrace);
      final List<WotdPastPick>? cached = blockSnapshotReady && _isTransientError(error) ? await _readArchive() : null;
      if (cached != null) return Result.success(_visiblePicks(cached));
      return Result.error(const ServerFailure("Couldn't load past picks. Check your connection and try again."));
    }
  }

  bool _isTransientFailure(Failure failure) =>
      failure is NetworkFailure ||
      const <String>{'unavailable', 'deadline-exceeded', 'network-request-failed', 'no-app'}.contains(failure.code);

  List<WotdPastPick> _visiblePicks(List<WotdPastPick> picks) {
    final Set<String> blocked = _userBlockRepository.cachedBlockedCreatorEmails;
    return picks
        .where((pick) => !BlockedCreatorsFilter.hidesCreatorEmail(pick.wallpaper.core.authorEmail, blocked))
        .toList(growable: false);
  }

  Future<({List<T> rows, bool authoritative})> _queryRecentRows<T>(
    FirestoreQuerySpec spec,
    T Function(Map<String, dynamic> data, String docId) map,
  ) async {
    final Completer<({List<T> rows, bool authoritative})> result = Completer<({List<T> rows, bool authoritative})>();
    StreamSubscription<({List<T> items, bool isFromCache})>? subscription;
    Timer? timeout;
    List<T> cachedRows = <T>[];
    bool receivedCache = false;
    timeout = Timer(const Duration(seconds: 8), () {
      if (!result.isCompleted) result.complete((rows: cachedRows, authoritative: false));
    });
    try {
      subscription = _firestoreClient
          .watchQueryWithMetadata<T>(spec, map)
          .listen(
            (snapshot) {
              if (snapshot.isFromCache) {
                cachedRows = snapshot.items;
                if (!receivedCache) {
                  receivedCache = true;
                  timeout?.cancel();
                  timeout = Timer(const Duration(milliseconds: 500), () {
                    if (!result.isCompleted) result.complete((rows: cachedRows, authoritative: false));
                  });
                }
              } else {
                if (!result.isCompleted) result.complete((rows: snapshot.items, authoritative: true));
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!result.isCompleted) result.completeError(error, stackTrace);
            },
            onDone: () {
              if (!result.isCompleted) result.complete((rows: cachedRows, authoritative: false));
            },
          );
    } catch (error, stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    }
    try {
      return await result.future;
    } finally {
      timeout?.cancel();
      final StreamSubscription<({List<T> items, bool isFromCache})>? active = subscription;
      if (active != null) {
        try {
          unawaited(
            active.cancel().catchError((Object error, StackTrace stackTrace) {
              logger.w('[WallOfTheDayRepository] past-picks query cancellation failed: $error\n$stackTrace');
            }),
          );
        } catch (error, stackTrace) {
          logger.w('[WallOfTheDayRepository] past-picks query cancellation failed: $error\n$stackTrace');
        }
      }
    }
  }

  bool _isTransientError(Object error) =>
      error is TimeoutException ||
      const <String>{
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
        'no-app',
      }.contains(mapFirestoreError(error).code);

  Future<void> _rememberToday(DateTime featuredUtc, String documentId, PrismWallpaper wallpaper) async {
    try {
      await _feedCacheLocal.write(
        source: 'wotd',
        scope: 'today',
        ttlHours: 24,
        payload: <String, Object?>{
          'featuredAtUtc': featuredUtc.toIso8601String(),
          'documentId': documentId,
          'item': encodeFeedItem(PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper)),
        },
      );
    } catch (error) {
      logger.w('[WallOfTheDayRepository] today snapshot write failed: $error');
    }
  }

  Future<void> _invalidateToday() async {
    _cached = null;
    try {
      await _feedCacheLocal.write(source: 'wotd', scope: 'today', ttlHours: 24, payload: <String, Object?>{});
    } catch (error) {
      logger.w('[WallOfTheDayRepository] today snapshot invalidation failed: $error');
    }
  }

  Future<WallOfTheDayEntity?> _readCachedToday(
    DateTime todayUtc,
    Set<String>? blocked, {
    String? wallDocumentId,
  }) async {
    try {
      final FeedSnapshot? snapshot = await _feedCacheLocal.read(source: 'wotd', scope: 'today');
      final Map<String, dynamic> payload = toJsonMap(snapshot?.payload);
      final DateTime? featuredAt = DateTime.tryParse(payload['featuredAtUtc']?.toString() ?? '')?.toUtc();
      if (featuredAt == null || !_isSameCalendarDayUtc(featuredAt, todayUtc)) return null;
      if (wallDocumentId != null && payload['documentId'] != wallDocumentId) return null;
      final FeedItemEntity? item = decodeFeedItem(toJsonMap(payload['item']));
      if (item is! PrismFeedItem || !hasPrismPreview(item.wallpaper) || item.wallpaper.review != true) return null;
      final WallOfTheDayEntity entity = wallOfTheDayEntityFromPrismWallpaper(item.wallpaper);
      return _visibleForCaller(
        entity,
        item.wallpaper.core.authorEmail,
        blocked ?? await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true),
      );
    } catch (error) {
      logger.w('[WallOfTheDayRepository] today snapshot read failed: $error');
      return null;
    }
  }

  List<WotdPastPick> _reconcileArchiveRows(
    List<({String docId, Map<String, dynamic> data})> rows,
    List<Result<WotdPastPick?>> resolved,
    List<WotdPastPick> cached,
  ) {
    final Map<String, WotdPastPick> cachedByDocumentId = <String, WotdPastPick>{
      for (final WotdPastPick pick in cached)
        if (pick.wallpaper.firestoreDocumentId != null) pick.wallpaper.firestoreDocumentId!: pick,
    };
    final List<WotdPastPick> available = <WotdPastPick>[];
    for (int index = 0; index < rows.length; index++) {
      final Result<WotdPastPick?> result = resolved[index];
      if (result.isSuccess && result.data != null) {
        available.add(result.data!);
      } else if (result.isFailure && _isTransientFailure(result.failure!)) {
        final String documentId = rows[index].data['wallId']?.toString() ?? '';
        final WotdPastPick? archived = cachedByDocumentId[documentId];
        if (archived != null) available.add(archived);
      }
    }
    return available;
  }

  Future<void> _writeArchive(List<WotdPastPick> picks) async {
    try {
      final List<Map<String, Object?>> cachedPicks = <Map<String, Object?>>[];
      for (final WotdPastPick pick in picks.take(100)) {
        final Map<String, Object?> entry = <String, Object?>{
          'dateUtc': pick.date.toUtc().toIso8601String(),
          'item': encodeFeedItem(PrismFeedItem(id: pick.wallpaper.id, wallpaper: pick.wallpaper)),
        };
        final List<Map<String, Object?>> candidate = <Map<String, Object?>>[...cachedPicks, entry];
        final Map<String, Object?> wrappedSnapshot = <String, Object?>{
          'cachedAtUtc': DateTime.now().toUtc().toIso8601String(),
          'ttlHours': 24,
          'payload': <String, Object?>{'picks': candidate},
        };
        if (utf8.encode(jsonEncode(wrappedSnapshot)).length <= FeedCacheLocalDataSource.maxSnapshotBytes) {
          cachedPicks.add(entry);
        }
      }
      await _feedCacheLocal.write(
        source: 'wotd',
        scope: 'archive',
        ttlHours: 24,
        payload: <String, Object?>{'picks': cachedPicks},
      );
    } catch (error) {
      logger.w('[WallOfTheDayRepository] archive snapshot write failed: $error');
    }
  }

  Future<List<WotdPastPick>?> _readArchive() async {
    try {
      final FeedSnapshot? snapshot = await _feedCacheLocal.read(source: 'wotd', scope: 'archive');
      final Object? rawPicks = toJsonMap(snapshot?.payload)['picks'];
      if (rawPicks is! List) return null;
      final List<WotdPastPick> picks = rawPicks
          .map((raw) {
            final Map<String, dynamic> entry = toJsonMap(raw);
            final DateTime? date = DateTime.tryParse(entry['dateUtc']?.toString() ?? '');
            final FeedItemEntity? item = decodeFeedItem(toJsonMap(entry['item']));
            if (date == null || item is! PrismFeedItem || item.wallpaper.review == false) return null;
            return WotdPastPick(date: date, wallpaper: item.wallpaper);
          })
          .nonNulls
          .toList(growable: false);
      return picks;
    } catch (error) {
      logger.w('[WallOfTheDayRepository] archive snapshot read failed: $error');
      return null;
    }
  }

  /// Null data means the wall is gone, hidden, not reviewed, or its pointer is malformed.
  Future<Result<WotdPastPick?>> _resolvePick(({String docId, Map<String, dynamic> data}) row) async {
    final String wallDocumentId = row.data['wallId']?.toString() ?? '';
    final DateTime? date = parseDateTime(row.data['date']) ?? DateTime.tryParse(row.docId);
    if (wallDocumentId.isEmpty || date == null) return Result.success(null);
    final Result<PrismWallpaper?> wall = await _prismWallpaperRepository.fetchByDocumentId(wallDocumentId);
    final PrismWallpaper? wallpaper = wall.data;
    if (wall.isFailure) return Result.error(wall.failure!);
    if (wallpaper == null || wallpaper.review != true || !hasPrismPreview(wallpaper)) return Result.success(null);
    return Result.success(WotdPastPick(date: date, wallpaper: wallpaper));
  }

  /// Hides the pick if its creator is on the caller's blocked list.
  WallOfTheDayEntity? _visibleForCaller(WallOfTheDayEntity? entity, String? authorEmail, Set<String> blocked) {
    if (entity == null) {
      return null;
    }
    return BlockedCreatorsFilter.hidesCreatorEmail(authorEmail, blocked) ? null : entity;
  }
}

class _CachedPick {
  const _CachedPick({
    required this.entity,
    required this.wallDocumentId,
    required this.featuredDayUtc,
    required this.authorEmail,
  });

  final WallOfTheDayEntity entity;
  final String wallDocumentId;
  final DateTime featuredDayUtc;
  final String? authorEmail;
}
