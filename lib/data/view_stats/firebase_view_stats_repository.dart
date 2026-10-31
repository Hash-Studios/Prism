import 'dart:async';

import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';

@LazySingleton(as: ViewStatsRepository)
class FirebaseViewStatsRepository implements ViewStatsRepository {
  FirebaseViewStatsRepository(this._firestoreClient);

  static const Duration _callableTimeout = Duration(seconds: 20);
  static const String _statsCollection = 'wallpaper_stats';

  final FirestoreClient _firestoreClient;
  final Map<(String, String), String> _viewsThisSession = <(String, String), String>{};
  final Map<(String, String), Future<Result<String>>> _viewsInFlight = <(String, String), Future<Result<String>>>{};

  @override
  Future<Result<String>> recordWallpaperView(String wallId) async {
    final String id = wallId.trim().toUpperCase();
    if (id.isEmpty) {
      return Result.error(const ServerFailure('Invalid wall id'));
    }
    final (String, String) key = (app_state.prismUser.loggedIn ? app_state.prismUser.id : '', id);
    final String? known = _viewsThisSession[key];
    if (known != null) return Result.success(known);
    final Future<Result<String>>? pending = _viewsInFlight[key];
    if (pending != null) return pending;
    final Future<Result<String>> request = _recordView(key, id);
    _viewsInFlight[key] = request;
    try {
      return await request;
    } finally {
      unawaited(_viewsInFlight.remove(key));
    }
  }

  Future<Result<String>> _recordView((String, String) key, String id) async {
    try {
      final cf.HttpsCallable callable = appFunctions.httpsCallable(
        'recordWallpaperView',
        options: cf.HttpsCallableOptions(timeout: _callableTimeout),
      );
      final cf.HttpsCallableResult result = await callable.call(<String, dynamic>{'wallId': id});
      final String views = _viewsString(result.data);
      _viewsThisSession[key] = views;
      return Result.success(views);
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure('Failed to record wallpaper view: ${e.message ?? e.code}'));
    } catch (e) {
      return Result.error(ServerFailure('Failed to record wallpaper view: $e'));
    }
  }

  @override
  Future<Result<WallpaperActionReceipt>> recordWallpaperAction(String wallId, WallpaperAction action) async {
    final owner = (app_state.prismUser.id, app_state.prismUser.loggedIn, CoinsService.instance.economySession);
    bool ownerMatches() =>
        owner == (app_state.prismUser.id, app_state.prismUser.loggedIn, CoinsService.instance.economySession);
    final String id = wallId.trim().toUpperCase();
    if (id.isEmpty) {
      return Result.error(const ServerFailure('Invalid wall id'));
    }
    try {
      final cf.HttpsCallable callable = appFunctions.httpsCallable(
        'recordWallpaperAction',
        options: cf.HttpsCallableOptions(timeout: _callableTimeout),
      );
      final String? requestId = DailyMomentConfig.enabled ? AnalyticsCorrelation.newId() : null;
      final payload = <String, dynamic>{
        'wallId': id,
        'action': action.wireValue,
        if (requestId != null) 'requestId': requestId,
      };
      for (var attempt = 0; attempt < 2; attempt++) {
        if (!ownerMatches()) return Result.error(const ServerFailure('Account changed'));
        try {
          final result = await callable.call(payload);
          if (!ownerMatches()) return Result.error(const ServerFailure('Account changed'));
          final Object? response = result.data;
          if (requestId != null && attempt == 0 && response is Map && response['questReceiptComplete'] == false) {
            continue;
          }
          return Result.success(
            requestId == null
                ? const WallpaperActionReceipt()
                : WallpaperActionReceipt.fromResponse(response, requestId),
          );
        } on cf.FirebaseFunctionsException catch (error) {
          if (requestId == null || attempt > 0 || (error.code != 'unavailable' && error.code != 'deadline-exceeded')) {
            rethrow;
          }
        }
      }
      return Result.success(const WallpaperActionReceipt());
    } on cf.FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') return Result.success(const WallpaperActionReceipt());
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
