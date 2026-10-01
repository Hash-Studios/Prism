import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_of_the_day/data/wotd_entity_mapper.dart';
import 'package:Prism/features/wall_of_the_day/data/wotd_firestore_pointer.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: WallOfTheDayRepository)
class WallOfTheDayRepositoryImpl implements WallOfTheDayRepository {
  WallOfTheDayRepositoryImpl(this._firestoreClient, this._prismWallpaperRepository, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final PrismWallpaperRepository _prismWallpaperRepository;
  final UserBlockRepository _userBlockRepository;

  _CachedPick? _cached;

  static bool _isSameCalendarDayUtc(DateTime a, DateTime b) {
    final au = a.toUtc();
    final bu = b.toUtc();
    return au.year == bu.year && au.month == bu.month && au.day == bu.day;
  }

  @override
  Future<Result<WallOfTheDayEntity?>> fetchToday() async {
    try {
      final WallOfTheDayFirestorePointer? pointer = await _firestoreClient.getById<WallOfTheDayFirestorePointer>(
        FirebaseCollections.wallOfTheDay,
        'current',
        (data, _) => WallOfTheDayFirestorePointer.fromMap(data),
        // Refresh the pointer while retaining Firestore's offline cache fallback.
        sourceTag: 'wotd.fetchToday.pointer',
      );

      if (pointer == null || pointer.wallDocumentId.isEmpty) {
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
        return Result.success(_visibleForCaller(cached.entity, cached.authorEmail));
      }

      final wallResult = await _prismWallpaperRepository.fetchByDocumentId(pointer.wallDocumentId);
      return await wallResult.fold(
        onSuccess: (wallpaper) {
          if (wallpaper == null || wallpaper.fullUrl.isEmpty) {
            return Result.success(null);
          }
          final WallOfTheDayEntity entity = wallOfTheDayEntityFromPrismWallpaper(wallpaper);
          _cached = _CachedPick(
            entity: entity,
            wallDocumentId: pointer.wallDocumentId,
            featuredDayUtc: featuredUtc,
            authorEmail: wallpaper.core.authorEmail,
          );
          return Result.success(_visibleForCaller(entity, wallpaper.core.authorEmail));
        },
        onFailure: (failure) => Result.error(failure),
      );
    } catch (e) {
      return Result.error(ServerFailure('Failed to fetch Wall of the Day: $e'));
    }
  }

  /// Hides the pick if its creator is on the caller's blocked list.
  WallOfTheDayEntity? _visibleForCaller(WallOfTheDayEntity? entity, String? authorEmail) {
    if (entity == null) {
      return null;
    }
    final blocked = _userBlockRepository.cachedBlockedCreatorEmails;
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
