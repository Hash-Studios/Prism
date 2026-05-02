import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';

@LazySingleton(as: ViewStatsRepository)
class FirebaseViewStatsRepository implements ViewStatsRepository {
  FirebaseViewStatsRepository();

  static const String _region = 'asia-south1';

  cf.FirebaseFunctions get _functions => cf.FirebaseFunctions.instanceFor(region: _region);

  static const Duration _callableTimeout = Duration(seconds: 20);

  @override
  Future<Result<String>> recordWallpaperView(String wallId) async {
    final String id = wallId.trim().toUpperCase();
    if (id.isEmpty) {
      return Result.error(const ServerFailure('Invalid wall id'));
    }
    try {
      final cf.HttpsCallable callable = _functions.httpsCallable(
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
  Future<Result<String>> recordSetupView(String setupId) async {
    final String id = setupId.trim().toUpperCase();
    if (id.isEmpty) {
      return Result.error(const ServerFailure('Invalid setup id'));
    }
    try {
      final cf.HttpsCallable callable = _functions.httpsCallable(
        'recordSetupView',
        options: cf.HttpsCallableOptions(timeout: _callableTimeout),
      );
      final cf.HttpsCallableResult result = await callable.call(<String, dynamic>{'setupId': id});
      return Result.success(_viewsString(result.data));
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure('Failed to record setup view: ${e.message ?? e.code}'));
    } catch (e) {
      return Result.error(ServerFailure('Failed to record setup view: $e'));
    }
  }

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
