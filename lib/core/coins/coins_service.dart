import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class CoinMutationResult {
  const CoinMutationResult({
    required this.success,
    required this.changed,
    required this.previousBalance,
    required this.currentBalance,
    required this.delta,
    this.bypassed = false,
    this.insufficientBalance = false,
    this.reason = '',
    this.transactionId = '',
  });

  final bool success;
  final bool changed;
  final bool bypassed;
  final bool insufficientBalance;
  final int previousBalance;
  final int currentBalance;
  final int delta;
  final String reason;
  final String transactionId;

  // ignore: prefer_constructors_over_static_methods
  static CoinMutationResult noChange({required int balance, String reason = '', bool success = true}) {
    return CoinMutationResult(
      success: success,
      changed: false,
      previousBalance: balance,
      currentBalance: balance,
      delta: 0,
      reason: reason,
    );
  }
}

class _AiGenerationReservationResult {
  const _AiGenerationReservationResult({required this.mode, required this.mutation, this.transactionId});

  final AiChargeMode mode;
  final CoinMutationResult mutation;
  final String? transactionId;

  bool get success => mode != AiChargeMode.insufficient && mutation.success;

  int get coinsSpent => mode == AiChargeMode.coinSpend && mutation.changed ? -mutation.delta : 0;
}

class StreakStatus {
  const StreakStatus({
    required this.streakDay,
    required this.active,
    required this.claimedToday,
    required this.reminderEnabled,
    required this.timezoneOffsetMinutes,
    required this.lastClaimDate,
    this.nextReminderAtUtc,
  });

  final int streakDay;
  final bool active;
  final bool claimedToday;
  final bool reminderEnabled;
  final int timezoneOffsetMinutes;
  final String lastClaimDate;
  final DateTime? nextReminderAtUtc;

  static const StreakStatus empty = StreakStatus(
    streakDay: 0,
    active: false,
    claimedToday: false,
    reminderEnabled: true,
    timezoneOffsetMinutes: 0,
    lastClaimDate: '',
  );

  StreakStatus copyWith({
    int? streakDay,
    bool? active,
    bool? claimedToday,
    bool? reminderEnabled,
    int? timezoneOffsetMinutes,
    String? lastClaimDate,
    DateTime? nextReminderAtUtc,
  }) {
    return StreakStatus(
      streakDay: streakDay ?? this.streakDay,
      active: active ?? this.active,
      claimedToday: claimedToday ?? this.claimedToday,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      lastClaimDate: lastClaimDate ?? this.lastClaimDate,
      nextReminderAtUtc: nextReminderAtUtc ?? this.nextReminderAtUtc,
    );
  }
}

class CoinsService {
  CoinsService._();

  static final CoinsService instance = CoinsService._();

  static const String _coinStateField = 'coinState';
  static const String _txCollection = FirebaseCollections.coinTransactions;
  static const String _pendingReferralInviterPrefKey = 'pendingReferralInviterId';
  static const String _streakReminderEnabledField = 'streakReminderEnabled';
  static const String _streakTimezoneOffsetMinutesField = 'streakTimezoneOffsetMinutes';
  static const String _streakReminderNextAtUtcField = 'streakReminderNextAtUtc';
  static const Duration _deltaAnimationDuration = Duration(milliseconds: 1400);
  static const Duration _premiumPreviewAccessDuration = Duration(hours: 24);
  final ValueNotifier<int> balanceNotifier = ValueNotifier<int>(app_state.prismUser.coins);
  final ValueNotifier<int> deltaNotifier = ValueNotifier<int>(0);
  final ValueNotifier<StreakStatus> streakNotifier = ValueNotifier<StreakStatus>(StreakStatus.empty);

  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  int _deltaVersion = 0;

  CoinMutationResult get _notLoggedIn =>
      CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');

  String? get pendingReferralInviterId {
    final String inviter = _settings.get<String>(_pendingReferralInviterPrefKey, defaultValue: '').trim();
    return inviter.isEmpty ? null : inviter;
  }

  Future<void> setPendingReferralInviterId(String inviterUserId) async {
    final String inviter = inviterUserId.trim();
    if (inviter.isEmpty) {
      return;
    }
    await _settings.set(_pendingReferralInviterPrefKey, inviter);
  }

  Future<void> clearPendingReferralInviterId() => _settings.delete(_pendingReferralInviterPrefKey);

  Future<void> setStreakReminderPreference(
    bool enabled, {
    String sourceTag = 'coins.streak_reminder.preference',
  }) async {
    if (_settings.isOpen) {
      await _settings.set(NotificationPrefKeys.streakReminders, enabled);
    }
    if (!_canMutateCoins()) {
      streakNotifier.value = streakNotifier.value.copyWith(reminderEnabled: enabled);
      return;
    }
    final String userId = app_state.prismUser.id;
    final int timezoneOffsetMinutes = _deviceTimezoneOffsetMinutes();
    await firestoreClient.runTransaction<void>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return;
        }
        final Map<String, dynamic> coinState = toJsonMap(data[_coinStateField]);
        final DateTime nowUtc = DateTime.now().toUtc();
        final String todayLocalKey = _offsetDayKey(nowUtc, timezoneOffsetMinutes);
        final String lastClaimDate = (coinState['lastDailyClaimDate'] as String? ?? '').trim();
        final int streakDay = _clampStreakDay(parseIntOr(coinState['streakDay']));
        final bool active =
            streakDay > 0 && (lastClaimDate == todayLocalKey || _isPreviousDay(lastClaimDate, todayLocalKey));
        // Rules only allow the client to write these specific coinState leaves, never the whole map.
        final Map<String, dynamic> updates = <String, dynamic>{
          '$_coinStateField.$_streakReminderEnabledField': enabled,
          '$_coinStateField.$_streakTimezoneOffsetMinutesField': timezoneOffsetMinutes,
        };
        if (enabled && active) {
          updates['$_coinStateField.$_streakReminderNextAtUtcField'] = _computeNextReminderAtUtc(
            nowUtc: nowUtc,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            lastClaimDate: lastClaimDate,
            todayLocalKey: todayLocalKey,
            activeStreak: true,
          );
        } else {
          updates['$_coinStateField.$_streakReminderNextAtUtcField'] = FirestoreSentinels.delete();
        }
        tx.updateDoc(FirebaseCollections.usersV2, userId, updates);
      },
      sourceTag: sourceTag,
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    await refreshStreakStatus();
  }

  Future<void> bootstrapForCurrentUser() async {
    if (!_canMutateCoins()) {
      return;
    }
    final String userId = app_state.prismUser.id;
    // The server owns coinState defaults now; the rules block writing it from the client,
    // so this only reads and defaults locally/in-memory instead of persisting anything.
    final Map<String, dynamic>? data = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (value, _) => value,
      sourceTag: 'coins.bootstrap',
    );
    if (data == null) {
      await refreshStreakStatus();
      return;
    }
    _applyLocalBalance(parseIntOr(data['coins']), delta: 0);
    _syncStreakFromUserData(data);
  }

  Future<int> refreshBalance() async {
    if (!_canMutateCoins()) {
      return app_state.prismUser.coins;
    }
    final String userId = app_state.prismUser.id;
    final Map<String, dynamic>? userData = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'coins.refresh_balance',
    );
    if (userData == null) {
      return app_state.prismUser.coins;
    }
    final int coins = parseIntOr(userData['coins']);
    _applyLocalBalance(coins, delta: 0);
    _syncStreakFromUserData(userData);
    return coins;
  }

  Future<StreakStatus> refreshStreakStatus() async {
    if (!_canMutateCoins()) {
      streakNotifier.value = StreakStatus.empty;
      return StreakStatus.empty;
    }
    final String userId = app_state.prismUser.id;
    final Map<String, dynamic>? userData = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'coins.refresh_streak',
    );
    if (userData == null) {
      return streakNotifier.value;
    }
    return _syncStreakFromUserData(userData);
  }

  Future<List<CoinTransactionEntry>> fetchTransactions({int limit = 100}) async {
    if (!_canMutateCoins()) {
      return const <CoinTransactionEntry>[];
    }
    final String userId = app_state.prismUser.id;
    try {
      final rows = await firestoreClient.query<CoinTransactionEntry>(
        FirestoreQuerySpec(
          collection: _txCollection,
          sourceTag: 'coins.transactions.fetch',
          filters: <FirestoreFilter>[FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId)],
          orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: limit,
          dedupeWindowMs: 1500,
        ),
        (data, docId) => CoinTransactionEntry.fromJson(data, fallbackId: docId),
      );
      return rows;
    } on FirestoreError catch (error, stackTrace) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }
      logCoinError(sourceTag: 'coins.transactions.fetch.missing_index_fallback', error: error, stackTrace: stackTrace);
      final fallbackRows = await firestoreClient.query<CoinTransactionEntry>(
        FirestoreQuerySpec(
          collection: _txCollection,
          sourceTag: 'coins.transactions.fetch.missing_index_fallback',
          filters: <FirestoreFilter>[FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId)],
          dedupeWindowMs: 1500,
        ),
        (data, docId) => CoinTransactionEntry.fromJson(data, fallbackId: docId),
      );
      fallbackRows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit <= 0 || fallbackRows.length <= limit) {
        return fallbackRows;
      }
      return fallbackRows.sublist(0, limit);
    }
  }

  Future<CoinMutationResult> award(
    CoinEarnAction action, {
    String sourceTag = 'coins.award',
    int? amountOverride,
    String? reason,
    String? transactionId,
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final bool isRefund = action == CoinEarnAction.refund;
    // Refunds are keyed by the debit's transactionId; the server ignores amount for them.
    final int? amount = isRefund ? null : (amountOverride ?? action.defaultAmount());
    if (!isRefund && (amount ?? 0) <= 0) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'invalid_amount');
    }
    final CoinMutationResult result = await _callCoinMutation(
      callableName: 'awardCoins',
      amount: amount,
      action: action.name,
      sourceTag: sourceTag,
      reason: reason ?? action.name,
      transactionId: transactionId,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) _logEarn(action: action, amount: amount ?? result.delta, sourceTag: sourceTag, reason: reason);
    return result;
  }

  Future<CoinMutationResult> spend(
    CoinSpendAction action, {
    String sourceTag = 'coins.spend',
    int? amountOverride,
    String? reason,
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final int amount = amountOverride ?? action.cost();
    if (amount <= 0) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'invalid_amount');
    }

    final CoinMutationResult result = await _callCoinMutation(
      callableName: 'spendCoins',
      amount: amount,
      action: action.name,
      sourceTag: sourceTag,
      reason: reason ?? action.name,
      allowPremiumBypass: true,
    );

    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) _logSpend(action: action, amount: amount, sourceTag: sourceTag, reason: reason);
    return result;
  }

  Future<CoinMutationResult> refundSpend(
    CoinSpendAction action, {
    required String sourceTag,
    required String transactionId,
    String? reason,
  }) {
    if (transactionId.trim().isEmpty) {
      return Future.value(
        CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'missing_transaction_id'),
      );
    }
    return award(
      CoinEarnAction.refund,
      sourceTag: sourceTag,
      reason: reason ?? 'refund_${action.name}',
      transactionId: transactionId,
    );
  }

  Future<_AiGenerationReservationResult> reserveForAiGeneration({
    required AiQualityTier qualityTier,
    String sourceTag = 'coins.reserve.ai_generation',
  }) async {
    if (!_canMutateCoins()) {
      return _AiGenerationReservationResult(
        mode: AiChargeMode.insufficient,
        mutation: CoinMutationResult.noChange(
          balance: app_state.prismUser.coins,
          success: false,
          reason: 'not_logged_in',
        ),
      );
    }
    final int cost = qualityTier.coinCost;
    final CoinMutationResult mutation = await _callCoinMutation(
      callableName: 'spendCoins',
      amount: cost,
      action: CoinSpendAction.aiGeneration.name,
      sourceTag: sourceTag,
      reason: 'ai_generation_reserved',
    );
    _applyLocalBalance(mutation.currentBalance, delta: mutation.delta);
    final _AiGenerationReservationResult result = _AiGenerationReservationResult(
      mode: mutation.changed ? AiChargeMode.coinSpend : AiChargeMode.insufficient,
      mutation: mutation,
      transactionId: mutation.transactionId,
    );
    if (result.mode == AiChargeMode.coinSpend && mutation.changed) {
      _logSpend(action: CoinSpendAction.aiGeneration, amount: cost, sourceTag: sourceTag, reason: 'ai_generation');
    }
    analytics.track(
      AiChargeReservedEvent(
        mode: aiChargeModeValueFromDomain(result.mode),
        coinsSpent: result.coinsSpent,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
      ),
    );
    return result;
  }

  Future<CoinMutationResult> rollbackAiGenerationReservation(
    AiChargeMode mode, {
    String sourceTag = 'coins.rollback.ai_generation',
    String? reservationTransactionId,
  }) async {
    if (mode == AiChargeMode.insufficient) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'no_reservation_to_rollback');
    }

    if (mode == AiChargeMode.coinSpend) {
      final CoinMutationResult refund = await refundSpend(
        CoinSpendAction.aiGeneration,
        transactionId: reservationTransactionId ?? '',
        sourceTag: sourceTag,
        reason: 'ai_generation_failed_refund',
      );
      if (refund.changed) {
        analytics.track(
          AiChargeRolledBackEvent(
            mode: aiChargeModeValueFromDomain(mode),
            coinsRefunded: refund.delta,
            balance: app_state.prismUser.coins,
            sourceTag: sourceTag,
          ),
        );
      }
      return refund;
    }

    return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'no_reservation_to_rollback');
  }

  void commitAiGenerationReservation({
    required AiChargeMode mode,
    required int coinsSpent,
    String sourceTag = 'coins.commit.ai_generation',
  }) {
    analytics.track(
      AiChargeCommittedEvent(
        mode: aiChargeModeValueFromDomain(mode),
        coinsSpent: coinsSpent,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
      ),
    );
  }

  Future<CoinMutationResult> spendForPremiumFilter({String sourceTag = 'coins.spend.premium_filter', String? reason}) {
    return spend(CoinSpendAction.premiumFilter, sourceTag: sourceTag, reason: reason ?? 'premium_filter');
  }

  Future<bool> hasPremiumPreviewAccessForCollection(String collectionKey) async {
    final String normalizedKey = _normalizeCollectionKey(collectionKey);
    if (normalizedKey.isEmpty) {
      return false;
    }
    if (app_state.prismUser.premium) {
      return true;
    }
    if (!_canMutateCoins()) {
      return false;
    }
    final String userId = app_state.prismUser.id;
    final Map<String, dynamic>? userData = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'coins.preview.check',
    );
    if (userData == null) {
      return false;
    }
    final bool isPremium = _isPremiumUserData(userData);
    if (isPremium) {
      return true;
    }
    final Map<String, int> previewUnlocks = _previewUnlocksFromState(toJsonMap(userData[_coinStateField]));
    return (previewUnlocks[normalizedKey] ?? 0) > DateTime.now().millisecondsSinceEpoch;
  }

  Future<CoinMutationResult> unlockPremiumPreview24hForCollection({
    required String collectionKey,
    String sourceTag = 'coins.preview.unlock',
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final String normalizedKey = _normalizeCollectionKey(collectionKey);
    if (normalizedKey.isEmpty) {
      return CoinMutationResult.noChange(
        balance: app_state.prismUser.coins,
        success: false,
        reason: 'invalid_collection_key',
      );
    }
    if (await hasPremiumPreviewAccessForCollection(normalizedKey)) {
      return CoinMutationResult.noChange(
        balance: app_state.prismUser.coins,
        reason: 'premium_preview_already_unlocked',
      );
    }
    final CoinMutationResult result = await _callCoinMutation(
      callableName: 'spendCoins',
      amount: CoinPolicy.premiumPreview24h,
      action: CoinSpendAction.premiumPreview24h.name,
      sourceTag: sourceTag,
      reason: 'premium_preview_unlock_24h',
      allowPremiumBypass: true,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed || result.bypassed) {
      final String userId = app_state.prismUser.id;
      final Map<String, dynamic>? data = await firestoreClient.getById<Map<String, dynamic>>(
        FirebaseCollections.usersV2,
        userId,
        (value, _) => value,
        sourceTag: '$sourceTag.read_state',
      );
      if (data == null) {
        return result;
      }
      final Map<String, int> previewUnlocks = _previewUnlocksFromState(toJsonMap(data[_coinStateField]));
      previewUnlocks[normalizedKey] =
          DateTime.now().millisecondsSinceEpoch + _premiumPreviewAccessDuration.inMilliseconds;
      // Rules only allow the client to write this nested leaf, never the whole coinState map.
      await firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
        '$_coinStateField.premiumPreviewUnlocks': previewUnlocks,
      }, sourceTag: sourceTag);
    }
    return result;
  }

  Future<CoinMutationResult> claimDailyLoginAndStreakIfEligible() async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final int previousBalance = app_state.prismUser.coins;
    final int timezoneOffsetMinutes = _deviceTimezoneOffsetMinutes();
    final bool reminderEnabled = _preferredStreakReminderEnabled();
    try {
      final HttpsCallable callable = appFunctions.httpsCallable(
        'claimDailyStreak',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final HttpsCallableResult<dynamic> response = await callable.call(<String, dynamic>{
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
        'reminderEnabled': reminderEnabled,
      });
      final Map<String, dynamic> payload = toJsonMap(response.data);

      final bool claimed = _asBool(payload['claimed']);
      final bool alreadyClaimedToday = _asBool(payload['alreadyClaimedToday']);
      final int streakDay = _clampStreakDay(parseIntOr(payload['streakDay']));
      final int dailyReward = parseIntOr(payload['dailyReward']);
      final int streakBonusReward = parseIntOr(payload['streakBonusReward']);
      final int totalReward = parseIntOr(payload['totalReward']);
      final int newBalance = parseIntOr(payload['newBalance']);
      final String todayLocalKey = (payload['todayLocalKey']?.toString() ?? '').trim();
      final int? nextReminderAtUtcMillis = payload['nextReminderAtUtcMillis'] == null
          ? null
          : parseIntOr(payload['nextReminderAtUtcMillis']);
      final int delta = newBalance - previousBalance;

      _applyLocalBalance(newBalance, delta: delta);
      streakNotifier.value = StreakStatus(
        streakDay: streakDay,
        active: streakDay > 0,
        claimedToday: claimed || alreadyClaimedToday,
        reminderEnabled: reminderEnabled,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        lastClaimDate: todayLocalKey,
        nextReminderAtUtc: nextReminderAtUtcMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(nextReminderAtUtcMillis, isUtc: true),
      );

      if (claimed) {
        String dailyReason = 'daily_login';
        if (streakDay >= 3 && streakDay <= 6) {
          dailyReason = 'streak_mid_cycle_day_$streakDay';
        } else if (streakDay == 7) {
          dailyReason = 'streak_day_7_daily';
        }
        if (dailyReward > 0) {
          _logEarn(
            action: CoinEarnAction.dailyLogin,
            amount: dailyReward,
            sourceTag: 'coins.claim_daily_and_streak',
            reason: dailyReason,
          );
        }
        if (streakBonusReward > 0) {
          _logEarn(
            action: CoinEarnAction.streakBonus,
            amount: streakBonusReward,
            sourceTag: 'coins.claim_daily_and_streak',
            reason: 'streak_day_7_bonus',
          );
        }
      }

      return CoinMutationResult(
        success: true,
        changed: claimed,
        previousBalance: previousBalance,
        currentBalance: newBalance,
        delta: totalReward > 0 ? totalReward : delta,
        reason: claimed ? 'daily_login' : 'daily_already_claimed',
      );
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.claim_daily_and_streak.callable', error: error, stackTrace: stackTrace);
      await refreshStreakStatus();
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'callable_failed');
    }
  }

  Future<CoinMutationResult> maybeAwardProDailyBonus() {
    return _awardFixed(
      CoinEarnAction.proDailyBonus,
      sourceTag: 'coins.claim_pro_daily_bonus',
      reason: 'pro_daily_bonus',
    );
  }

  Future<CoinMutationResult> maybeAwardProfileCompletion() {
    if (!_canMutateCoins()) {
      return Future.value(_notLoggedIn);
    }
    if (!_isProfileComplete()) {
      return Future.value(
        CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'profile_incomplete'),
      );
    }
    return _awardFixed(
      CoinEarnAction.profileCompletion,
      sourceTag: 'coins.profile_completion',
      reason: 'profile_completion',
    );
  }

  Future<CoinMutationResult> maybeAwardFirstWallpaperUpload() {
    return _awardFixed(
      CoinEarnAction.firstWallpaperUpload,
      sourceTag: 'coins.first_wallpaper_upload',
      reason: 'first_wallpaper_upload',
    );
  }

  Future<CoinMutationResult> processPendingReferralIfEligible({String? inviterUserId}) async {
    if (inviterUserId != null && inviterUserId.trim().isNotEmpty) {
      await setPendingReferralInviterId(inviterUserId);
    }
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final String currentUserId = app_state.prismUser.id;
    final String? pendingInviter = pendingReferralInviterId;
    if (pendingInviter == null || pendingInviter.isEmpty) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'no_pending_referral');
    }
    if (pendingInviter == currentUserId) {
      await clearPendingReferralInviterId();
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'self_referral');
    }

    final CoinMutationResult result = await _awardFixed(
      CoinEarnAction.referral,
      sourceTag: 'coins.process_referral',
      reason: pendingInviter,
      logReason: 'referee_reward',
      callableName: 'processReferral',
      inviterUserId: pendingInviter,
    );
    if (result.changed || result.reason == 'referral_already_processed') {
      await clearPendingReferralInviterId();
    }
    return result;
  }

  Future<CoinMutationResult> _awardFixed(
    CoinEarnAction action, {
    required String sourceTag,
    required String reason,
    String? logReason,
    String callableName = 'awardCoins',
    String? inviterUserId,
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final CoinMutationResult result = await _callCoinMutation(
      callableName: callableName,
      amount: action.defaultAmount(),
      action: action.name,
      sourceTag: sourceTag,
      reason: reason,
      inviterUserId: inviterUserId,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logEarn(action: action, amount: action.defaultAmount(), sourceTag: sourceTag, reason: logReason);
    }
    return result;
  }

  bool _canMutateCoins() {
    return app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty;
  }

  Future<CoinMutationResult> _callCoinMutation({
    required String callableName,
    int? amount,
    required String action,
    required String sourceTag,
    required String reason,
    bool allowPremiumBypass = false,
    String? inviterUserId,
    String? transactionId,
  }) async {
    try {
      final HttpsCallable callable = appFunctions.httpsCallable(callableName);
      final HttpsCallableResult<dynamic> response = await callable.call(<String, dynamic>{
        if (amount != null) 'amount': amount,
        'action': action,
        'reason': reason,
        'sourceTag': sourceTag,
        'allowPremiumBypass': allowPremiumBypass,
        if (inviterUserId != null) 'inviterUserId': inviterUserId,
        if (transactionId != null) 'transactionId': transactionId,
      });
      final Map<String, dynamic> data = toJsonMap(response.data);
      final int balance = parseIntOr(data['currentBalance']);
      return CoinMutationResult(
        success: data['success'] == true,
        changed: data['changed'] == true,
        bypassed: data['bypassed'] == true,
        insufficientBalance: data['insufficientBalance'] == true,
        previousBalance: parseIntOr(data['previousBalance']),
        currentBalance: balance,
        delta: parseIntOr(data['delta']),
        reason: data['reason']?.toString() ?? reason,
        transactionId: data['transactionId']?.toString() ?? '',
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      logCoinError(sourceTag: '$sourceTag.callable', error: error, stackTrace: stackTrace);
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: error.code);
    }
  }

  bool _isProfileComplete() {
    final ProfileCompletenessStatus status = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    return status.isComplete;
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final String normalized = (value?.toString() ?? '').toLowerCase().trim();
    return normalized == 'true' || normalized == '1';
  }

  bool _isPremiumUserData(Map<String, dynamic> data) {
    final bool premiumFlag = _asBool(data['premium']) || app_state.prismUser.premium;
    final SubscriptionTier tierFromGlobal = SubscriptionTier.fromValue(app_state.prismUser.subscriptionTier);
    if (tierFromGlobal.isPaid) {
      return true;
    }
    final SubscriptionTier tierFromDoc = SubscriptionTier.fromValue(data['subscriptionTier']?.toString());
    return premiumFlag || tierFromDoc.isPaid;
  }

  int _deviceTimezoneOffsetMinutes() {
    return DateTime.now().timeZoneOffset.inMinutes;
  }

  bool _preferredStreakReminderEnabled() {
    if (!_settings.isOpen) {
      return true;
    }
    return _settings.get<bool>(NotificationPrefKeys.streakReminders, defaultValue: true);
  }

  int _clampStreakDay(int day) {
    if (day < 0) {
      return 0;
    }
    if (day > 7) {
      return 7;
    }
    return day;
  }

  DateTime _offsetDateTime(DateTime utc, int timezoneOffsetMinutes) {
    return utc.add(Duration(minutes: timezoneOffsetMinutes));
  }

  String _offsetDayKey(DateTime utc, int timezoneOffsetMinutes) {
    final DateTime shifted = _offsetDateTime(utc.toUtc(), timezoneOffsetMinutes);
    final String month = shifted.month.toString().padLeft(2, '0');
    final String day = shifted.day.toString().padLeft(2, '0');
    return '${shifted.year}-$month-$day';
  }

  DateTime? _parseUtcDateTime(Object? value) => parseDateTime(value)?.toUtc();

  DateTime _computeNextReminderAtUtc({
    required DateTime nowUtc,
    required int timezoneOffsetMinutes,
    required String lastClaimDate,
    required String todayLocalKey,
    required bool activeStreak,
  }) {
    DateTime reminderLocalBase(DateTime localBase, {required bool tomorrow}) {
      final int dayOffset = tomorrow ? 1 : 0;
      // Build this in UTC so scheduling doesn't depend on the device timezone.
      return DateTime.utc(localBase.year, localBase.month, localBase.day + dayOffset, 20);
    }

    final DateTime localNow = _offsetDateTime(nowUtc, timezoneOffsetMinutes);
    final bool claimedToday = lastClaimDate == todayLocalKey;
    final bool sendTomorrow = !activeStreak || claimedToday || localNow.hour >= 20;
    final DateTime localReminder = reminderLocalBase(localNow, tomorrow: sendTomorrow);
    return localReminder.subtract(Duration(minutes: timezoneOffsetMinutes)).toUtc();
  }

  StreakStatus _syncStreakFromUserData(Map<String, dynamic> userData) {
    final Map<String, dynamic> coinState = toJsonMap(userData[_coinStateField]);
    final int timezoneOffsetMinutes =
        parseInt(coinState[_streakTimezoneOffsetMinutesField]) ?? _deviceTimezoneOffsetMinutes();
    final String todayLocalKey = _offsetDayKey(DateTime.now().toUtc(), timezoneOffsetMinutes);
    final String lastClaimDate = (coinState['lastDailyClaimDate'] as String? ?? '').trim();
    final int streakDay = _clampStreakDay(parseIntOr(coinState['streakDay']));
    final bool active =
        streakDay > 0 && (lastClaimDate == todayLocalKey || _isPreviousDay(lastClaimDate, todayLocalKey));
    final bool claimedToday = lastClaimDate == todayLocalKey;
    final StreakStatus status = StreakStatus(
      streakDay: active ? streakDay : 0,
      active: active,
      claimedToday: claimedToday,
      reminderEnabled: _asBool(coinState[_streakReminderEnabledField] ?? _preferredStreakReminderEnabled()),
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      lastClaimDate: lastClaimDate,
      nextReminderAtUtc: _parseUtcDateTime(coinState[_streakReminderNextAtUtcField]),
    );
    streakNotifier.value = status;
    return status;
  }

  Map<String, int> _previewUnlocksFromState(Map<String, dynamic> coinState) {
    return _previewUnlocksFromRaw(coinState['premiumPreviewUnlocks']);
  }

  Map<String, int> _previewUnlocksFromRaw(Object? raw) {
    if (raw is! Map) {
      return <String, int>{};
    }
    final Map<String, int> normalized = <String, int>{};
    raw.forEach((key, value) {
      final String normalizedKey = _normalizeCollectionKey(key.toString());
      if (normalizedKey.isEmpty) {
        return;
      }
      final int expiryMillis = parseIntOr(value);
      if (expiryMillis > 0) {
        normalized[normalizedKey] = expiryMillis;
      }
    });
    return normalized;
  }

  String _normalizeCollectionKey(String rawKey) {
    return rawKey.trim().toLowerCase();
  }

  bool _isPreviousDay(String previousDay, String currentDay) {
    final DateTime? previous = DateTime.tryParse(previousDay);
    final DateTime? current = DateTime.tryParse(currentDay);
    if (previous == null || current == null) {
      return false;
    }
    final DateTime previousUtcDate = DateTime.utc(previous.year, previous.month, previous.day);
    final DateTime currentUtcDate = DateTime.utc(current.year, current.month, current.day);
    return currentUtcDate.difference(previousUtcDate).inDays == 1;
  }

  void _applyLocalBalance(int newBalance, {required int delta}) {
    final int previous = app_state.prismUser.coins;
    app_state.prismUser.coins = newBalance;
    balanceNotifier.value = newBalance;
    if (delta == 0 && previous == newBalance) {
      return;
    }
    if (_settings.isOpen) {
      app_state.persistPrismUser();
    }
    _deltaVersion += 1;
    final int currentVersion = _deltaVersion;
    deltaNotifier.value = delta;
    Future<void>.delayed(_deltaAnimationDuration, () {
      if (_deltaVersion == currentVersion) {
        deltaNotifier.value = 0;
      }
    });
  }

  void _logEarn({required CoinEarnAction action, required int amount, required String sourceTag, String? reason}) {
    analytics.track(
      CoinEarnedEvent(
        action: coinEarnActionValueFromDomain(action),
        amount: amount,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
        reason: reason != null && reason.isNotEmpty ? reason : null,
      ),
    );
  }

  void _logSpend({required CoinSpendAction action, required int amount, required String sourceTag, String? reason}) {
    analytics.track(
      CoinSpentEvent(
        action: coinSpendActionValueFromDomain(action),
        amount: amount,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
        reason: reason != null && reason.isNotEmpty ? reason : null,
      ),
    );
  }

  void logLowBalanceNudge({required String sourceTag, required int requiredCoins}) {
    analytics.track(
      CoinLowBalanceNudgeShownEvent(
        sourceTag: sourceTag,
        requiredCoins: requiredCoins,
        balance: app_state.prismUser.coins,
      ),
    );
  }

  void logWatchAndDownloadUsed({required bool isPremiumContent, required String sourceTag}) {
    analytics.track(CoinWatchAndDownloadUsedEvent(isPremiumContent: isPremiumContent, sourceTag: sourceTag));
  }

  void logCoinError({required String sourceTag, required Object error, StackTrace? stackTrace}) {
    logger.e(
      'Coin service error',
      tag: 'Coins',
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'sourceTag': sourceTag},
    );
  }
}
