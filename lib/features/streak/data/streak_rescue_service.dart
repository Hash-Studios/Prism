import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Price of a streak rescue. The server owns the real value and checks the balance.
const int kStreakRescueCost = 100;

/// A streak must be at least this long before a break can be rescued.
const int kStreakRescueMinCount = 7;

/// A paid streak rescue the user can still buy. [count] is the streak length before the break.
class StreakRescueOffer {
  const StreakRescueOffer(this.count);

  final int count;

  /// The server writes the offer in the same call that reports a break of a long streak.
  static StreakRescueOffer? fromClaim(StreakClaimResult claim) {
    if (!claim.streakBroken || claim.previousStreakCount < kStreakRescueMinCount) return null;
    return StreakRescueOffer(claim.previousStreakCount);
  }
}

enum StreakRescueOutcome { restored, insufficientBalance, unavailable, failed }

class StreakRescueResult {
  const StreakRescueResult(this.outcome, {this.streakCount = 0, this.reason = ''});

  final StreakRescueOutcome outcome;
  final int streakCount;
  final String reason;

  bool get isRestored => outcome == StreakRescueOutcome.restored;
}

typedef StreakRescueCall = Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// Buys a streak back through the `restoreStreak` callable. One request id covers every retry of the same buy.
class StreakRescueService {
  StreakRescueService({
    StreakRescueCall? call,
    SettingsLocalDataSource? settings,
    String Function()? newRequestId,
    Future<void> Function()? refreshBalance,
  }) : _call = call ?? _callRestoreStreak,
       _settings = settings,
       _newRequestId = newRequestId ?? _randomRequestId,
       _refreshBalance = refreshBalance ?? _refreshCoins;

  static final StreakRescueService instance = StreakRescueService();

  final StreakRescueCall _call;
  final SettingsLocalDataSource? _settings;
  final String Function() _newRequestId;
  final Future<void> Function() _refreshBalance;

  SettingsLocalDataSource get _store => _settings ?? getIt<SettingsLocalDataSource>();

  static Future<Map<String, dynamic>> _callRestoreStreak(Map<String, dynamic> data) async {
    final HttpsCallable callable = appFunctions.httpsCallable(
      'restoreStreak',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    final HttpsCallableResult<dynamic> response = await callable.call(data);
    return toJsonMap(response.data);
  }

  static Future<void> _refreshCoins() async {
    await CoinsService.instance.refreshBalance();
  }

  static String _randomRequestId() {
    final Random random = Random.secure();
    final String suffix = List<String>.generate(16, (_) => random.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  Future<StreakRescueResult> restore() async {
    final user = app_state.prismUser;
    if (!user.loggedIn || user.id.trim().isEmpty) return _finish(const StreakRescueResult(StreakRescueOutcome.failed));
    final SettingsLocalDataSource store = _store;
    final String pendingKey = 'pendingStreakRescueRequest.${user.id}';
    final String persisted = store.isOpen ? store.get<String>(pendingKey, defaultValue: '') : '';
    final String requestId = persisted.isNotEmpty ? persisted : _newRequestId();
    if (store.isOpen && persisted.isEmpty) await store.set(pendingKey, requestId);

    Future<void> clearPending() async {
      if (store.isOpen) await store.delete(pendingKey);
    }

    try {
      final Map<String, dynamic> data = await _call(<String, dynamic>{'requestId': requestId});
      final String reason = data['reason']?.toString() ?? '';
      if (data['success'] == true) {
        await clearPending();
        try {
          await _refreshBalance();
        } catch (error, stackTrace) {
          logger.w(
            'Balance refresh after streak rescue failed',
            tag: 'streak_rescue',
            error: error,
            stackTrace: stackTrace,
          );
        }
        return _finish(StreakRescueResult(StreakRescueOutcome.restored, streakCount: parseIntOr(data['streakCount'])));
      }
      await clearPending();
      if (data['insufficientBalance'] == true || reason == 'streak_rescue_insufficient_balance') {
        return _finish(StreakRescueResult(StreakRescueOutcome.insufficientBalance, reason: reason));
      }
      return _finish(StreakRescueResult(StreakRescueOutcome.unavailable, reason: reason));
    } on FirebaseFunctionsException catch (error, stackTrace) {
      logger.w('restoreStreak failed', tag: 'streak_rescue', error: error, stackTrace: stackTrace);
      if (error.code == 'not-found' || error.code == 'unimplemented') {
        await clearPending();
        return _finish(StreakRescueResult(StreakRescueOutcome.unavailable, reason: error.code));
      }
      return _finish(StreakRescueResult(StreakRescueOutcome.failed, reason: error.code));
    } catch (error, stackTrace) {
      logger.w('restoreStreak failed', tag: 'streak_rescue', error: error, stackTrace: stackTrace);
      return _finish(const StreakRescueResult(StreakRescueOutcome.failed));
    }
  }

  StreakRescueResult _finish(StreakRescueResult result) {
    analytics.track(StreakRescueUsedEvent(result: result.outcome.name));
    return result;
  }
}
