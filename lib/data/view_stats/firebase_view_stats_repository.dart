import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';

@LazySingleton(as: ViewStatsRepository)
class FirebaseViewStatsRepository implements ViewStatsRepository {
  FirebaseViewStatsRepository(this._firestoreClient);

  static const Duration _callableTimeout = Duration(seconds: 20);
  static const String _statsCollection = 'wallpaper_stats';

  final FirestoreClient _firestoreClient;

  @override
  Future<Result<String>> recordWallpaperView(String wallId) async {
    final String id = wallId.trim().toUpperCase();
    if (id.isEmpty) {
      return Result.error(const ServerFailure('Invalid wall id'));
    }
    try {
      final cf.HttpsCallable callable = appFunctions.httpsCallable(
        'recordWallpaperView',
        options: cf.HttpsCallableOptions(timeout: _callableTimeout),
      );
      final cf.HttpsCallableResult result = await callable.call(<String, dynamic>{'wallId': id});
      return Result.success(_viewsString(result.data));
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure('Failed to record wallpaper view: ${e.message ?? e.code}'));
    } catch (e) {
      return Result.error(ServerFailure('Failed to record wallpaper view: $e'));
    }
  }

  @override
  Future<Result<void>> recordWallpaperAction(String wallId, WallpaperAction action) async {
    final String id = wallId.trim().toUpperCase();
    if (id.isEmpty) {
      return Result.error(const ServerFailure('Invalid wall id'));
    }
    try {
      final cf.HttpsCallable callable = appFunctions.httpsCallable(
        'recordWallpaperAction',
        options: cf.HttpsCallableOptions(timeout: _callableTimeout),
      );
      await callable.call(<String, dynamic>{'wallId': id, 'action': action.wireValue});
      return Result.success(null);
    } on cf.FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') return Result.success(null);
      return Result.error(ServerFailure('Failed to record wallpaper action: ${e.message ?? e.code}'));
    } catch (e) {
      return Result.error(ServerFailure('Failed to record wallpaper action: $e'));
    }
  }

  @override
  Future<Result<int?>> fetchWallpaperSetCount(String wallId) async {
    final String id = wallId.trim().toUpperCase();
    if (id.isEmpty) {
      return Result.error(const ServerFailure('Invalid wall id'));
    }
    try {
      final int? sets = await _firestoreClient.getById<int?>(
        _statsCollection,
        id,
        (data, _) => _count(data['sets']),
        sourceTag: 'wallpaper_stats.detail',
      );
      return Result.success(sets);
    } catch (e) {
      return Result.error(ServerFailure('Failed to read wallpaper stats: $e'));
    }
  }

  static int? _count(Object? raw) => raw is num ? raw.toInt() : null;

  static String _viewsString(Object? data) {
    if (data is Map) {
      final Object? raw = data['views'];
      if (raw is int) {
        return raw.toString();
      }
      if (raw is num) {
        return raw.toInt().toString();
      }
      if (raw is String) {
        return raw;
      }
    }
    return '0';
  }
}
