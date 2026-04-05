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

  WallOfTheDayEntity? _cachedEntity;
  String? _cachedWallDocumentId;
  DateTime? _cachedFeaturedDayUtc;

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
        sourceTag: 'wotd.fetchToday.pointer',
        preferCacheFirst: true,
      );

      if (pointer == null || pointer.wallDocumentId.isEmpty) {
        return Result.success(null);
      }

      final DateTime featuredUtc = pointer.featuredAt.toUtc();
      if (_cachedEntity != null &&
          _cachedWallDocumentId == pointer.wallDocumentId &&
          _cachedFeaturedDayUtc != null &&
          _isSameCalendarDayUtc(_cachedFeaturedDayUtc!, featuredUtc)) {
        return Result.success(_cachedEntity);
      }

      final wallResult = await _prismWallpaperRepository.fetchByDocumentId(pointer.wallDocumentId);
      return wallResult.fold(
        onSuccess: (wallpaper) {
          if (wallpaper == null) {
            return Result.success(null);
          }
          final Set<String> blocked = _userBlockRepository.cachedBlockedCreatorEmails;
          if (BlockedCreatorsFilter.hidesCreatorEmail(wallpaper.core.authorEmail, blocked)) {
            return Result.success(null);
          }
          if (wallpaper.fullUrl.isEmpty) {
            return Result.success(null);
          }
          final WallOfTheDayEntity entity = wallOfTheDayEntityFromPrismWallpaper(wallpaper, pointer.featuredAt);
          _cachedEntity = entity;
          _cachedWallDocumentId = pointer.wallDocumentId;
          _cachedFeaturedDayUtc = featuredUtc;
          return Result.success(entity);
        },
        onFailure: (failure) => Result.error(failure),
      );
    } catch (e) {
      return Result.error(ServerFailure('Failed to fetch Wall of the Day: $e'));
    }
  }
}
