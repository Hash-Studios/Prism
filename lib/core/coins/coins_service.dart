import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  });

  final bool success;
  final bool changed;
  final bool bypassed;
  final bool insufficientBalance;
  final int previousBalance;
  final int currentBalance;
  final int delta;
  final String reason;

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
  static const String _txStatusReserved = 'reserved';
  static const String _txStatusCompleted = 'completed';
  static const String _txStatusRolledBack = 'rolled_back';
  static const String _shareDomain = 'prismwalls.com';
  static const String _shortLinkApiUrl = 'https://prismwalls.com/api/links';
  static const String _pendingReferralInviterPrefKey = 'pendingReferralInviterId';
  static const String _streakReminderPrefKey = 'streakReminderSubscriber';
  static const String _streakReminderEnabledField = 'streakReminderEnabled';
  static const String _streakTimezoneOffsetMinutesField = 'streakTimezoneOffsetMinutes';
  static const String _streakReminderNextAtUtcField = 'streakReminderNextAtUtc';
  static const String _streakReminderLastSentDateField = 'streakReminderLastSentDate';
  static const String _streakLastClaimServerAtField = 'streakLastClaimServerAt';
  static const Duration _deltaAnimationDuration = Duration(milliseconds: 1400);
  static const Duration _premiumPreviewAccessDuration = Duration(hours: 24);
  static const Duration _shortLinkTimeout = Duration(seconds: 6);
  final ValueNotifier<int> balanceNotifier = ValueNotifier<int>(app_state.prismUser.coins);
  final ValueNotifier<int> deltaNotifier = ValueNotifier<int>(0);
  final ValueNotifier<StreakStatus> streakNotifier = ValueNotifier<StreakStatus>(StreakStatus.empty);
  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  int _deltaVersion = 0;

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

  bool get streakReminderPreferenceEnabled => _preferredStreakReminderEnabled();

  Future<void> setStreakReminderPreference(
    bool enabled, {
    String sourceTag = 'coins.streak_reminder.preference',
  }) async {
    if (_settings.isOpen) {
      await _settings.set(_streakReminderPrefKey, enabled);
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
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState, reminderEnabled: enabled, timezoneOffsetMinutes: timezoneOffsetMinutes);
        final DateTime nowUtc = DateTime.now().toUtc();
        final String todayLocalKey = _offsetDayKey(nowUtc, timezoneOffsetMinutes);
        final String lastClaimDate = (coinState['lastDailyClaimDate'] as String? ?? '').trim();
        final int streakDay = _clampStreakDay(_asInt(coinState['streakDay']));
        final bool active =
            streakDay > 0 && (lastClaimDate == todayLocalKey || _isPreviousDay(lastClaimDate, todayLocalKey));
        coinState[_streakReminderEnabledField] = enabled;
        coinState[_streakTimezoneOffsetMinutesField] = timezoneOffsetMinutes;
        if (enabled && active) {
          final DateTime nextReminderAtUtc = _computeNextReminderAtUtc(
            nowUtc: nowUtc,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            lastClaimDate: lastClaimDate,
            todayLocalKey: todayLocalKey,
            activeStreak: true,
          );
          coinState[_streakReminderNextAtUtcField] = nextReminderAtUtc;
        } else {
          coinState.remove(_streakReminderNextAtUtcField);
        }
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{_coinStateField: coinState});
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
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final int coins = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        final bool stateChanged = _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        if (stateChanged || data['coins'] == null) {
          tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
            'coins': coins,
            _coinStateField: coinState,
          });
        }
        return CoinMutationResult.noChange(balance: coins);
      },
      sourceTag: 'coins.bootstrap',
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    _applyLocalBalance(result.currentBalance, delta: 0);
    await refreshStreakStatus();
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
    final int coins = _asInt(userData['coins']);
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
  }) async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final int amount = amountOverride ?? action.defaultAmount();
    if (amount <= 0) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'invalid_amount');
    }
    final String userId = app_state.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final int previous = _asInt(data['coins']);
        final int current = previous + amount;
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        return CoinMutationResult(
          success: true,
          changed: true,
          previousBalance: previous,
          currentBalance: current,
          delta: amount,
          reason: reason ?? action.name,
        );
      },
      sourceTag: sourceTag,
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    _logEarn(action: action, amount: amount, sourceTag: sourceTag, reason: reason);
    if (result.changed) {
      await _recordCoinTransaction(
        userId: userId,
        id: _newTransactionId(action.name),
        delta: amount,
        balanceBefore: result.previousBalance,
        balanceAfter: result.currentBalance,
        action: action.name,
        description: _earnDescription(action, amount, reason: reason),
        sourceTag: sourceTag,
        reason: reason,
        status: _txStatusCompleted,
      );
    }
    return result;
  }

  Future<CoinMutationResult> spend(
    CoinSpendAction action, {
    String sourceTag = 'coins.spend',
    int? amountOverride,
    bool bypassForPremium = true,
    String? reason,
  }) async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final int amount = amountOverride ?? action.cost();
    if (amount <= 0) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'invalid_amount');
    }

    final String userId = app_state.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final bool isPremium = _isPremiumUserData(data);
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        if (isPremium && bypassForPremium) {
          return CoinMutationResult(
            success: true,
            changed: false,
            previousBalance: previous,
            currentBalance: previous,
            delta: 0,
            bypassed: true,
            reason: reason ?? '${action.name}_premium_bypass',
          );
        }
        if (previous < amount) {
          return CoinMutationResult(
            success: false,
            changed: false,
            previousBalance: previous,
            currentBalance: previous,
            delta: 0,
            insufficientBalance: true,
            reason: reason ?? '${action.name}_insufficient_balance',
          );
        }
        final int current = previous - amount;
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        return CoinMutationResult(
          success: true,
          changed: true,
          previousBalance: previous,
          currentBalance: current,
          delta: -amount,
          reason: reason ?? action.name,
        );
      },
      sourceTag: sourceTag,
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );

    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logSpend(action: action, amount: amount, sourceTag: sourceTag, reason: reason);
      await _recordCoinTransaction(
        userId: userId,
        id: _newTransactionId(action.name),
        delta: -amount,
        balanceBefore: result.previousBalance,
        balanceAfter: result.currentBalance,
        action: action.name,
        description: _spendDescription(action, amount, reason: reason),
        sourceTag: sourceTag,
        reason: reason,
        status: _txStatusCompleted,
      );
    }
    return result;
  }

  Future<CoinMutationResult> refundSpend(
    CoinSpendAction action, {
    required String sourceTag,
    int? amountOverride,
    String? reason,
  }) {
    return award(
      CoinEarnAction.refund,
      amountOverride: amountOverride ?? action.cost(),
      sourceTag: sourceTag,
      reason: reason ?? 'refund_${action.name}',
    );
  }

  Future<_AiGenerationReservationResult> reserveForAiGeneration({
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
    final String userId = app_state.prismUser.id;
    final String today = _localDayKey(DateTime.now());
    final _AiGenerationReservationResult result = await firestoreClient.runTransaction<_AiGenerationReservationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return _AiGenerationReservationResult(
            mode: AiChargeMode.insufficient,
            mutation: CoinMutationResult.noChange(
              balance: app_state.prismUser.coins,
              success: false,
              reason: 'user_missing',
            ),
          );
        }
        final int previous = _asInt(data['coins']);
        final bool isPremium = _isPremiumUserData(data);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );

        if (!isPremium) {
          final int freeUsed = _asInt(coinState['aiFreeUsedTotal']);
          if (freeUsed < 3) {
            coinState['aiFreeUsedTotal'] = freeUsed + 1;
            tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
              'coins': previous,
              _coinStateField: coinState,
            });
            return _AiGenerationReservationResult(
              mode: AiChargeMode.freeTrial,
              mutation: CoinMutationResult(
                success: true,
                changed: true,
                previousBalance: previous,
                currentBalance: previous,
                delta: 0,
                reason: 'ai_free_trial_reserved',
              ),
            );
          }
        } else {
          final String includedDate = (coinState['aiIncludedUsageDate'] as String? ?? '').trim();
          int includedUsed = _asInt(coinState['aiIncludedUsedToday']);
          if (includedDate != today) {
            includedUsed = 0;
          }
          if (includedUsed < 30) {
            coinState['aiIncludedUsageDate'] = today;
            coinState['aiIncludedUsedToday'] = includedUsed + 1;
            tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
              'coins': previous,
              _coinStateField: coinState,
            });
            return _AiGenerationReservationResult(
              mode: AiChargeMode.proIncluded,
              mutation: CoinMutationResult(
                success: true,
                changed: true,
                previousBalance: previous,
                currentBalance: previous,
                delta: 0,
                reason: 'ai_pro_included_reserved',
              ),
            );
          }
        }

        if (previous < CoinPolicy.aiGeneration) {
          return _AiGenerationReservationResult(
            mode: AiChargeMode.insufficient,
            mutation: CoinMutationResult(
              success: false,
              changed: false,
              previousBalance: previous,
              currentBalance: previous,
              delta: 0,
              insufficientBalance: true,
              reason: 'ai_generation_insufficient_balance',
            ),
          );
        }

        final int current = previous - CoinPolicy.aiGeneration;
        final String txId = _newTransactionId('ai_generation');
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        tx.setDoc(_txCollection, txId, <String, dynamic>{
          'id': txId,
          'userId': userId,
          'createdAt': DateTime.now().toUtc(),
          'updatedAt': DateTime.now().toUtc(),
          'delta': -CoinPolicy.aiGeneration,
          'balanceBefore': previous,
          'balanceAfter': current,
          'action': CoinSpendAction.aiGeneration.name,
          'description': 'AI wallpaper generation (-${CoinPolicy.aiGeneration})',
          'sourceTag': sourceTag,
          'reason': 'ai_generation_reserved',
          'status': _txStatusReserved,
          'type': 'debit',
          'referenceType': 'ai_generation',
        });
        return _AiGenerationReservationResult(
          mode: AiChargeMode.coinSpend,
          mutation: CoinMutationResult(
            success: true,
            changed: true,
            previousBalance: previous,
            currentBalance: current,
            delta: -CoinPolicy.aiGeneration,
            reason: 'ai_coin_spend_reserved',
          ),
          transactionId: txId,
        );
      },
      sourceTag: sourceTag,
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );

    _applyLocalBalance(result.mutation.currentBalance, delta: result.mutation.delta);
    if (result.mode == AiChargeMode.coinSpend && result.mutation.changed) {
      _logSpend(
        action: CoinSpendAction.aiGeneration,
        amount: CoinPolicy.aiGeneration,
        sourceTag: sourceTag,
        reason: 'ai_generation',
      );
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
      await _markTransactionRolledBack(reservationTransactionId, sourceTag: sourceTag, reason: 'ai_generation_failed');
      final CoinMutationResult refund = await refundSpend(
        CoinSpendAction.aiGeneration,
        sourceTag: sourceTag,
        reason: 'ai_generation_failed_refund',
      );
      analytics.track(
        AiChargeRolledBackEvent(
          mode: aiChargeModeValueFromDomain(mode),
          coinsRefunded: CoinPolicy.aiGeneration,
          balance: app_state.prismUser.coins,
          sourceTag: sourceTag,
        ),
      );
      return refund;
    }

    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String userId = app_state.prismUser.id;
    final String today = _localDayKey(DateTime.now());
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        bool changed = false;

        if (mode == AiChargeMode.freeTrial) {
          final int freeUsed = _asInt(coinState['aiFreeUsedTotal']);
          if (freeUsed > 0) {
            coinState['aiFreeUsedTotal'] = freeUsed - 1;
            changed = true;
          }
        } else if (mode == AiChargeMode.proIncluded) {
          final String includedDate = (coinState['aiIncludedUsageDate'] as String? ?? '').trim();
          final int includedUsed = _asInt(coinState['aiIncludedUsedToday']);
          if (includedDate == today && includedUsed > 0) {
            coinState['aiIncludedUsedToday'] = includedUsed - 1;
            changed = true;
          }
        }

        if (changed) {
          tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
            'coins': previous,
            _coinStateField: coinState,
          });
        }
        return CoinMutationResult(
          success: true,
          changed: changed,
          previousBalance: previous,
          currentBalance: previous,
          delta: 0,
          reason: changed ? 'ai_${mode.value}_rollback' : 'ai_${mode.value}_rollback_noop',
        );
      },
      sourceTag: sourceTag,
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    analytics.track(
      AiChargeRolledBackEvent(
        mode: aiChargeModeValueFromDomain(mode),
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
      ),
    );
    return result;
  }

  void commitAiGenerationReservation({
    required AiChargeMode mode,
    required int coinsSpent,
    String sourceTag = 'coins.commit.ai_generation',
    String? reservationTransactionId,
    String? generationId,
    String? imageUrl,
    String? thumbUrl,
    String? prompt,
    String? stylePreset,
  }) {
    analytics.track(
      AiChargeCommittedEvent(
        mode: aiChargeModeValueFromDomain(mode),
        coinsSpent: coinsSpent,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
      ),
    );
    if (mode == AiChargeMode.coinSpend) {
      unawaited(
        _completeAiGenerationTransaction(
          reservationTransactionId: reservationTransactionId,
          generationId: generationId,
          imageUrl: imageUrl,
          thumbUrl: thumbUrl,
          prompt: prompt,
          stylePreset: stylePreset,
          sourceTag: sourceTag,
        ),
      );
    }
  }

  Future<CoinMutationResult> spendForAIGeneration({String sourceTag = 'coins.spend.ai_generation', String? reason}) {
    return spend(CoinSpendAction.aiGeneration, sourceTag: sourceTag, reason: reason ?? 'ai_generation');
  }

  Future<CoinMutationResult> spendForPremiumFilter({String sourceTag = 'coins.spend.premium_filter', String? reason}) {
    return spend(CoinSpendAction.premiumFilter, sourceTag: sourceTag, reason: reason ?? 'premium_filter');
  }

  Future<CoinMutationResult> spendForPremiumPreview24h({
    String sourceTag = 'coins.spend.premium_preview_24h',
    String? reason,
  }) {
    return spend(CoinSpendAction.premiumPreview24h, sourceTag: sourceTag, reason: reason ?? 'premium_preview_24h');
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
    final Map<String, dynamic> coinState = _coinStateFromRaw(userData[_coinStateField]);
    _ensureCoinStateDefaults(
      coinState,
      reminderEnabled: _preferredStreakReminderEnabled(),
      timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
    );
    final Map<String, int> previewUnlocks = _previewUnlocksFromState(coinState);
    return (previewUnlocks[normalizedKey] ?? 0) > DateTime.now().millisecondsSinceEpoch;
  }

  Future<CoinMutationResult> unlockPremiumPreview24hForCollection({
    required String collectionKey,
    String sourceTag = 'coins.preview.unlock',
  }) async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String normalizedKey = _normalizeCollectionKey(collectionKey);
    if (normalizedKey.isEmpty) {
      return CoinMutationResult.noChange(
        balance: app_state.prismUser.coins,
        success: false,
        reason: 'invalid_collection_key',
      );
    }
    final String userId = app_state.prismUser.id;
    final int nowMillis = DateTime.now().millisecondsSinceEpoch;
    final int expiryMillis = nowMillis + _premiumPreviewAccessDuration.inMilliseconds;
    const int previewCost = CoinPolicy.premiumPreview24h;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final bool isPremium = _isPremiumUserData(data);
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        final Map<String, int> previewUnlocks = _previewUnlocksFromState(coinState);
        final bool pruned = _pruneExpiredPreviewUnlocks(previewUnlocks, nowMillis: nowMillis);
        final int existingExpiry = previewUnlocks[normalizedKey] ?? 0;

        void persistPreviewStateOnly() {
          coinState['premiumPreviewUnlocks'] = previewUnlocks;
          tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
            'coins': previous,
            _coinStateField: coinState,
          });
        }

        if (isPremium) {
          if (pruned) {
            persistPreviewStateOnly();
          }
          return CoinMutationResult(
            success: true,
            changed: false,
            previousBalance: previous,
            currentBalance: previous,
            delta: 0,
            bypassed: true,
            reason: 'premium_bypass',
          );
        }

        if (existingExpiry > nowMillis) {
          if (pruned) {
            persistPreviewStateOnly();
          }
          return CoinMutationResult.noChange(balance: previous, reason: 'premium_preview_already_unlocked');
        }

        if (previous < previewCost) {
          if (pruned) {
            persistPreviewStateOnly();
          }
          return CoinMutationResult(
            success: false,
            changed: false,
            previousBalance: previous,
            currentBalance: previous,
            delta: 0,
            insufficientBalance: true,
            reason: 'premium_preview_insufficient_balance',
          );
        }

        previewUnlocks[normalizedKey] = expiryMillis;
        final int current = previous - previewCost;
        coinState['premiumPreviewUnlocks'] = previewUnlocks;
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        return CoinMutationResult(
          success: true,
          changed: true,
          previousBalance: previous,
          currentBalance: current,
          delta: -previewCost,
          reason: 'premium_preview_unlock_24h',
        );
      },
      sourceTag: sourceTag,
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logSpend(
        action: CoinSpendAction.premiumPreview24h,
        amount: previewCost,
        sourceTag: sourceTag,
        reason: 'collection_$normalizedKey',
      );
      await _recordCoinTransaction(
        userId: userId,
        id: _newTransactionId(CoinSpendAction.premiumPreview24h.name),
        delta: -previewCost,
        balanceBefore: result.previousBalance,
        balanceAfter: result.currentBalance,
        action: CoinSpendAction.premiumPreview24h.name,
        description: 'Premium collection preview unlock (-$previewCost)',
        sourceTag: sourceTag,
        reason: 'collection_$normalizedKey',
        status: _txStatusCompleted,
        referenceType: 'collection',
        referenceId: normalizedKey,
      );
    }
    return result;
  }

  Future<CoinMutationResult> claimDailyLoginAndStreakIfEligible() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final int previousBalance = app_state.prismUser.coins;
    final int timezoneOffsetMinutes = _deviceTimezoneOffsetMinutes();
    final bool reminderEnabled = _preferredStreakReminderEnabled();
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('claimDailyStreak');
      final HttpsCallableResult<dynamic> response = await callable.call(<String, dynamic>{
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
        'reminderEnabled': reminderEnabled,
      });
      final Map<String, dynamic> payload = _asStringDynamicMap(response.data);

      final bool claimed = _asBool(payload['claimed']);
      final bool alreadyClaimedToday = _asBool(payload['alreadyClaimedToday']);
      final int streakDay = _clampStreakDay(_asInt(payload['streakDay']));
      final int dailyReward = _asInt(payload['dailyReward']);
      final int streakBonusReward = _asInt(payload['streakBonusReward']);
      final int totalReward = _asInt(payload['totalReward']);
      final int newBalance = _asInt(payload['newBalance']);
      final String todayLocalKey = (payload['todayLocalKey']?.toString() ?? '').trim();
      final int? nextReminderAtUtcMillis = payload['nextReminderAtUtcMillis'] == null
          ? null
          : _asInt(payload['nextReminderAtUtcMillis']);
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

  Future<CoinMutationResult> maybeAwardProDailyBonus() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String userId = app_state.prismUser.id;
    final String today = _localDayKey(DateTime.now());
    CoinMutationResult? result;
    const int maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        result = await firestoreClient.runTransaction<CoinMutationResult>(
          (tx) async {
            final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
            if (data == null) {
              return CoinMutationResult.noChange(
                balance: app_state.prismUser.coins,
                success: false,
                reason: 'user_missing',
              );
            }
            final bool isPremium = _isPremiumUserData(data);
            final int previous = _asInt(data['coins']);
            if (!isPremium) {
              return CoinMutationResult.noChange(balance: previous, reason: 'not_premium');
            }
            final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
            _ensureCoinStateDefaults(
              coinState,
              reminderEnabled: _preferredStreakReminderEnabled(),
              timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
            );
            final String lastBonusDate = (coinState['proDailyBonusDate'] as String? ?? '').trim();
            if (lastBonusDate == today) {
              return CoinMutationResult.noChange(balance: previous, reason: 'pro_bonus_already_claimed');
            }
            final int current = previous + CoinPolicy.proDailyBonus;
            coinState['proDailyBonusDate'] = today;
            tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
              'coins': current,
              _coinStateField: coinState,
            });
            return CoinMutationResult(
              success: true,
              changed: true,
              previousBalance: previous,
              currentBalance: current,
              delta: CoinPolicy.proDailyBonus,
              reason: 'pro_daily_bonus',
            );
          },
          sourceTag: 'coins.claim_pro_daily_bonus',
          collection: FirebaseCollections.usersV2,
          docId: userId,
        );
        break;
      } on FirestoreError catch (e) {
        if (e.code == 'unavailable' && attempt < maxRetries - 1) {
          await Future<void>.delayed(Duration(seconds: (attempt + 1) * 2));
          continue;
        }
        rethrow;
      }
    }
    result ??= CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'unavailable');

    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logEarn(
        action: CoinEarnAction.proDailyBonus,
        amount: CoinPolicy.proDailyBonus,
        sourceTag: 'coins.claim_pro_daily_bonus',
      );
      await _recordCoinTransaction(
        userId: userId,
        id: _newTransactionId(CoinEarnAction.proDailyBonus.name),
        delta: CoinPolicy.proDailyBonus,
        balanceBefore: result.previousBalance,
        balanceAfter: result.currentBalance,
        action: CoinEarnAction.proDailyBonus.name,
        description: 'Pro daily bonus (+${CoinPolicy.proDailyBonus})',
        sourceTag: 'coins.claim_pro_daily_bonus',
        reason: 'pro_daily_bonus',
        status: _txStatusCompleted,
      );
    }
    return result;
  }

  Future<CoinMutationResult> maybeAwardProfileCompletion() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    if (!_isProfileComplete()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'profile_incomplete');
    }
    final String userId = app_state.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        if (_asBool(coinState['profileCompletionRewarded'])) {
          return CoinMutationResult.noChange(balance: previous, reason: 'profile_reward_already_claimed');
        }
        final int current = previous + CoinPolicy.profileCompletion;
        coinState['profileCompletionRewarded'] = true;
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        return CoinMutationResult(
          success: true,
          changed: true,
          previousBalance: previous,
          currentBalance: current,
          delta: CoinPolicy.profileCompletion,
          reason: 'profile_completion',
        );
      },
      sourceTag: 'coins.profile_completion',
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logEarn(
        action: CoinEarnAction.profileCompletion,
        amount: CoinPolicy.profileCompletion,
        sourceTag: 'coins.profile_completion',
      );
      await _recordCoinTransaction(
        userId: userId,
        id: _newTransactionId(CoinEarnAction.profileCompletion.name),
        delta: CoinPolicy.profileCompletion,
        balanceBefore: result.previousBalance,
        balanceAfter: result.currentBalance,
        action: CoinEarnAction.profileCompletion.name,
        description: 'Profile completion reward (+${CoinPolicy.profileCompletion})',
        sourceTag: 'coins.profile_completion',
        reason: 'profile_completion',
        status: _txStatusCompleted,
      );
    }
    return result;
  }

  Future<CoinMutationResult> maybeAwardFirstWallpaperUpload() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String userId = app_state.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(
          coinState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        if (_asBool(coinState['firstWallpaperUploadRewarded'])) {
          return CoinMutationResult.noChange(balance: previous, reason: 'first_upload_reward_already_claimed');
        }
        final int current = previous + CoinPolicy.firstWallpaperUpload;
        coinState['firstWallpaperUploadRewarded'] = true;
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        return CoinMutationResult(
          success: true,
          changed: true,
          previousBalance: previous,
          currentBalance: current,
          delta: CoinPolicy.firstWallpaperUpload,
          reason: 'first_wallpaper_upload',
        );
      },
      sourceTag: 'coins.first_wallpaper_upload',
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logEarn(
        action: CoinEarnAction.firstWallpaperUpload,
        amount: CoinPolicy.firstWallpaperUpload,
        sourceTag: 'coins.first_wallpaper_upload',
      );
      await _recordCoinTransaction(
        userId: userId,
        id: _newTransactionId(CoinEarnAction.firstWallpaperUpload.name),
        delta: CoinPolicy.firstWallpaperUpload,
        balanceBefore: result.previousBalance,
        balanceAfter: result.currentBalance,
        action: CoinEarnAction.firstWallpaperUpload.name,
        description: 'First wallpaper upload reward (+${CoinPolicy.firstWallpaperUpload})',
        sourceTag: 'coins.first_wallpaper_upload',
        reason: 'first_wallpaper_upload',
        status: _txStatusCompleted,
      );
    }
    return result;
  }

  Future<CoinMutationResult> processPendingReferralIfEligible({String? inviterUserId}) async {
    if (inviterUserId != null && inviterUserId.trim().isNotEmpty) {
      await setPendingReferralInviterId(inviterUserId);
    }
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');
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

    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? currentData = await tx.getDoc(FirebaseCollections.usersV2, currentUserId);
        if (currentData == null) {
          return CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'user_missing',
          );
        }
        final int currentPrevious = _asInt(currentData['coins']);
        final Map<String, dynamic> currentState = _coinStateFromRaw(currentData[_coinStateField]);
        _ensureCoinStateDefaults(
          currentState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );
        if (_asBool(currentState['referralRewarded'])) {
          return CoinMutationResult.noChange(balance: currentPrevious, reason: 'referral_already_processed');
        }

        final String existingReferrer = (currentState['referredByUserId'] as String? ?? '').trim();
        final String effectiveInviter = existingReferrer.isNotEmpty ? existingReferrer : pendingInviter;
        if (effectiveInviter.isEmpty || effectiveInviter == currentUserId) {
          return CoinMutationResult.noChange(balance: currentPrevious, reason: 'invalid_inviter');
        }

        final Map<String, dynamic>? inviterData = await tx.getDoc(FirebaseCollections.usersV2, effectiveInviter);
        if (inviterData == null) {
          return CoinMutationResult.noChange(balance: currentPrevious, reason: 'inviter_missing');
        }

        final int inviterPrevious = _asInt(inviterData['coins']);
        final Map<String, dynamic> inviterState = _coinStateFromRaw(inviterData[_coinStateField]);
        _ensureCoinStateDefaults(
          inviterState,
          reminderEnabled: _preferredStreakReminderEnabled(),
          timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
        );

        final int currentAfter = currentPrevious + CoinPolicy.referral;
        final int inviterAfter = inviterPrevious + CoinPolicy.referral;

        currentState['referredByUserId'] = effectiveInviter;
        currentState['referralRewarded'] = true;

        tx.updateDoc(FirebaseCollections.usersV2, currentUserId, <String, dynamic>{
          'coins': currentAfter,
          _coinStateField: currentState,
        });
        tx.updateDoc(FirebaseCollections.usersV2, effectiveInviter, <String, dynamic>{
          'coins': inviterAfter,
          _coinStateField: inviterState,
        });
        final String inviterTxId = _newTransactionId('referral');
        tx.setDoc(_txCollection, inviterTxId, <String, dynamic>{
          'id': inviterTxId,
          'userId': effectiveInviter,
          'createdAt': DateTime.now().toUtc(),
          'updatedAt': DateTime.now().toUtc(),
          'delta': CoinPolicy.referral,
          'balanceBefore': inviterPrevious,
          'balanceAfter': inviterAfter,
          'action': CoinEarnAction.referral.name,
          'description': 'Referral reward (+${CoinPolicy.referral})',
          'sourceTag': 'coins.process_referral',
          'reason': 'inviter_reward',
          'status': _txStatusCompleted,
          'type': 'credit',
          'referenceType': 'referral',
          'referenceId': currentUserId,
        });

        return CoinMutationResult(
          success: true,
          changed: true,
          previousBalance: currentPrevious,
          currentBalance: currentAfter,
          delta: CoinPolicy.referral,
          reason: 'referral_rewarded',
        );
      },
      sourceTag: 'coins.process_referral',
      collection: FirebaseCollections.usersV2,
      docId: currentUserId,
    );

    if (result.changed || result.reason == 'referral_already_processed') {
      await clearPendingReferralInviterId();
    }

    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logEarn(
        action: CoinEarnAction.referral,
        amount: CoinPolicy.referral,
        sourceTag: 'coins.process_referral',
        reason: 'referee_reward',
      );
      await _recordCoinTransaction(
        userId: currentUserId,
        id: _newTransactionId(CoinEarnAction.referral.name),
        delta: CoinPolicy.referral,
        balanceBefore: result.previousBalance,
        balanceAfter: result.currentBalance,
        action: CoinEarnAction.referral.name,
        description: 'Referral reward (+${CoinPolicy.referral})',
        sourceTag: 'coins.process_referral',
        reason: 'referee_reward',
        status: _txStatusCompleted,
        referenceType: 'referral',
      );
    }
    return result;
  }

  Future<void> _recordCoinTransaction({
    required String userId,
    required String id,
    required int delta,
    required int balanceBefore,
    required int balanceAfter,
    required String action,
    required String description,
    required String sourceTag,
    required String status,
    String? reason,
    String? referenceType,
    String? referenceId,
    String? deepLinkUrl,
    String? shortLinkUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final entry = CoinTransactionEntry(
        id: id,
        userId: userId,
        createdAt: now,
        updatedAt: now,
        delta: delta,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        action: action,
        description: description,
        sourceTag: sourceTag,
        status: status,
        type: delta >= 0 ? 'credit' : 'debit',
        reason: reason,
        referenceType: referenceType,
        referenceId: referenceId,
        deepLinkUrl: deepLinkUrl,
        shortLinkUrl: shortLinkUrl,
        metadata: metadata,
      );
      await firestoreClient.setDoc(_txCollection, id, entry.toJson(), merge: true, sourceTag: '$sourceTag.tx_write');
    } catch (error, stackTrace) {
      logCoinError(sourceTag: '$sourceTag.tx_write', error: error, stackTrace: stackTrace);
    }
  }

  String _newTransactionId(String key) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int random = Random().nextInt(1 << 31);
    return 'ctx_${key}_${now}_${random.toRadixString(16)}';
  }

  String _earnDescription(CoinEarnAction action, int amount, {String? reason}) {
    switch (action) {
      case CoinEarnAction.rewardedAd:
        return 'Rewarded ad credit (+$amount)';
      case CoinEarnAction.dailyLogin:
        return 'Daily login reward (+$amount)';
      case CoinEarnAction.streakBonus:
        return 'Streak bonus (+$amount)';
      case CoinEarnAction.firstWallpaperUpload:
        return 'First wallpaper upload reward (+$amount)';
      case CoinEarnAction.referral:
        return 'Referral reward (+$amount)';
      case CoinEarnAction.profileCompletion:
        return 'Profile completion reward (+$amount)';
      case CoinEarnAction.proDailyBonus:
        return 'Pro daily bonus (+$amount)';
      case CoinEarnAction.refund:
        if ((reason ?? '').contains('ai_generation_failed_refund')) {
          return 'AI generation refund (+$amount)';
        }
        return 'Coins refunded (+$amount)';
    }
  }

  String _spendDescription(CoinSpendAction action, int amount, {String? reason}) {
    switch (action) {
      case CoinSpendAction.wallpaperDownload:
        return 'Wallpaper download (-$amount)';
      case CoinSpendAction.premiumWallpaperDownload:
        return 'Premium wallpaper download (-$amount)';
      case CoinSpendAction.aiGeneration:
        return 'AI wallpaper generation (-$amount)';
      case CoinSpendAction.premiumFilter:
        return 'Premium filter use (-$amount)';
      case CoinSpendAction.premiumPreview24h:
        if ((reason ?? '').startsWith('collection_')) {
          return 'Premium collection preview unlock (-$amount)';
        }
        return 'Premium preview unlock (-$amount)';
    }
  }

  Future<void> _markTransactionRolledBack(String? transactionId, {required String sourceTag, String? reason}) async {
    if (transactionId == null || transactionId.trim().isEmpty) {
      return;
    }
    try {
      await firestoreClient.updateDoc(_txCollection, transactionId, <String, dynamic>{
        'status': _txStatusRolledBack,
        'reason': reason ?? 'rolled_back',
        'updatedAt': DateTime.now().toUtc(),
      }, sourceTag: '$sourceTag.tx_mark_rollback');
    } catch (error, stackTrace) {
      logCoinError(sourceTag: '$sourceTag.tx_mark_rollback', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _completeAiGenerationTransaction({
    required String? reservationTransactionId,
    required String? generationId,
    required String? imageUrl,
    required String? thumbUrl,
    required String? prompt,
    required String? stylePreset,
    required String sourceTag,
  }) async {
    final String txId = reservationTransactionId?.trim() ?? '';
    final String genId = generationId?.trim() ?? '';
    if (txId.isEmpty || genId.isEmpty) {
      return;
    }

    final Uri canonical = _buildAiCanonicalShareUri(generationId: genId, imageUrl: imageUrl, thumbUrl: thumbUrl);
    final String shortUrl = await _createShortLinkForAiGeneration(
      generationId: genId,
      canonicalUri: canonical,
      imageSourceUrl: thumbUrl,
      prompt: prompt,
      stylePreset: stylePreset,
    );
    try {
      await firestoreClient.updateDoc(_txCollection, txId, <String, dynamic>{
        'status': _txStatusCompleted,
        'updatedAt': DateTime.now().toUtc(),
        'referenceType': 'ai_generation',
        'referenceId': genId,
        'deepLinkUrl': canonical.toString(),
        'shortLinkUrl': shortUrl,
        'description': 'AI wallpaper generation (-${CoinPolicy.aiGeneration})',
        'metadata': <String, dynamic>{
          if (prompt != null && prompt.trim().isNotEmpty) 'prompt': prompt.trim(),
          if (stylePreset != null && stylePreset.trim().isNotEmpty) 'stylePreset': stylePreset.trim(),
        },
      }, sourceTag: '$sourceTag.tx_complete');
    } catch (error, stackTrace) {
      logCoinError(sourceTag: '$sourceTag.tx_complete', error: error, stackTrace: stackTrace);
    }
  }

  Uri _buildAiCanonicalShareUri({required String generationId, required String? imageUrl, required String? thumbUrl}) {
    final String resolvedImage = (imageUrl ?? '').trim();
    final String resolvedThumb = (thumbUrl ?? resolvedImage).trim();
    return Uri.https(_shareDomain, '/share', <String, String>{
      'id': generationId,
      'provider': 'Prism',
      if (resolvedImage.isNotEmpty) 'url': resolvedImage,
      if (resolvedThumb.isNotEmpty) 'thumb': resolvedThumb,
    });
  }

  Future<String> _createShortLinkForAiGeneration({
    required String generationId,
    required Uri canonicalUri,
    required String? imageSourceUrl,
    required String? prompt,
    required String? stylePreset,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_shortLinkApiUrl),
            headers: const <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'type': 'share',
              'payload': <String, dynamic>{
                'id': generationId,
                'provider': 'Prism',
                'url': canonicalUri.queryParameters['url'],
                'thumb': canonicalUri.queryParameters['thumb'],
              },
              'canonical_url': canonicalUri.toString(),
              'preview': <String, dynamic>{
                'title': 'AI $generationId - Prism',
                'description': 'Generated with Prism AI${(stylePreset ?? '').trim().isEmpty ? '' : ' ($stylePreset)'}',
                if ((imageSourceUrl ?? '').trim().isNotEmpty) 'image_source_url': imageSourceUrl!.trim(),
                if ((prompt ?? '').trim().isNotEmpty) 'prompt': prompt!.trim(),
                'provider': 'Prism',
                'wall_id': generationId,
              },
            }),
          )
          .timeout(_shortLinkTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return canonicalUri.toString();
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic shortUrl = decoded['short_url'];
        if (shortUrl is String && shortUrl.trim().isNotEmpty) {
          return shortUrl.trim();
        }
      }
    } catch (_) {
      return canonicalUri.toString();
    }
    return canonicalUri.toString();
  }

  bool _canMutateCoins() {
    return app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty;
  }

  bool _isProfileComplete() {
    final ProfileCompletenessStatus status = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    return status.isComplete;
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _asStringDynamicMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
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

  Map<String, dynamic> _coinStateFromRaw(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  bool _ensureCoinStateDefaults(
    Map<String, dynamic> coinState, {
    required bool reminderEnabled,
    required int timezoneOffsetMinutes,
  }) {
    bool changed = false;
    changed |= _putDefaultIfMissing(coinState, 'lastDailyClaimDate', '');
    changed |= _putDefaultIfMissing(coinState, 'streakDay', 0);
    changed |= _putDefaultIfMissing(coinState, 'profileCompletionRewarded', false);
    changed |= _putDefaultIfMissing(coinState, 'firstWallpaperUploadRewarded', false);
    changed |= _putDefaultIfMissing(coinState, 'proDailyBonusDate', '');
    changed |= _putDefaultIfMissing(coinState, 'referredByUserId', '');
    changed |= _putDefaultIfMissing(coinState, 'referralRewarded', false);
    changed |= _putDefaultIfMissing(coinState, 'premiumPreviewUnlocks', <String, int>{});
    changed |= _putDefaultIfMissing(coinState, 'aiFreeUsedTotal', 0);
    changed |= _putDefaultIfMissing(coinState, 'aiIncludedUsageDate', '');
    changed |= _putDefaultIfMissing(coinState, 'aiIncludedUsedToday', 0);
    changed |= _putDefaultIfMissing(coinState, _streakReminderEnabledField, reminderEnabled);
    changed |= _putDefaultIfMissing(coinState, _streakTimezoneOffsetMinutesField, timezoneOffsetMinutes);
    changed |= _putDefaultIfMissing(coinState, _streakReminderLastSentDateField, '');
    changed |= _putDefaultIfMissing(coinState, _streakLastClaimServerAtField, '');
    final Map<String, int> normalizedPreviewUnlocks = _previewUnlocksFromState(coinState);
    if (!_previewUnlockStateEquals(coinState['premiumPreviewUnlocks'], normalizedPreviewUnlocks)) {
      coinState['premiumPreviewUnlocks'] = normalizedPreviewUnlocks;
      changed = true;
    }
    final int normalizedStreakDay = _clampStreakDay(_asInt(coinState['streakDay']));
    if (normalizedStreakDay != _asInt(coinState['streakDay'])) {
      coinState['streakDay'] = normalizedStreakDay;
      changed = true;
    }
    return changed;
  }

  int _deviceTimezoneOffsetMinutes() {
    return DateTime.now().timeZoneOffset.inMinutes;
  }

  bool _preferredStreakReminderEnabled() {
    if (!_settings.isOpen) {
      return true;
    }
    return _settings.get<bool>(_streakReminderPrefKey, defaultValue: true);
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

  DateTime? _parseUtcDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    final dynamic raw = value;
    try {
      final dynamic maybeDate = raw.toDate();
      if (maybeDate is DateTime) {
        return maybeDate.toUtc();
      }
    } catch (_) {}
    return DateTime.tryParse(value.toString())?.toUtc();
  }

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
    final Map<String, dynamic> coinState = _coinStateFromRaw(userData[_coinStateField]);
    _ensureCoinStateDefaults(
      coinState,
      reminderEnabled: _preferredStreakReminderEnabled(),
      timezoneOffsetMinutes: _deviceTimezoneOffsetMinutes(),
    );
    final int timezoneOffsetMinutes = _asInt(coinState[_streakTimezoneOffsetMinutesField]);
    final String todayLocalKey = _offsetDayKey(DateTime.now().toUtc(), timezoneOffsetMinutes);
    final String lastClaimDate = (coinState['lastDailyClaimDate'] as String? ?? '').trim();
    final int streakDay = _clampStreakDay(_asInt(coinState['streakDay']));
    final bool active =
        streakDay > 0 && (lastClaimDate == todayLocalKey || _isPreviousDay(lastClaimDate, todayLocalKey));
    final bool claimedToday = lastClaimDate == todayLocalKey;
    final StreakStatus status = StreakStatus(
      streakDay: active ? streakDay : 0,
      active: active,
      claimedToday: claimedToday,
      reminderEnabled: _asBool(coinState[_streakReminderEnabledField]),
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      lastClaimDate: lastClaimDate,
      nextReminderAtUtc: _parseUtcDateTime(coinState[_streakReminderNextAtUtcField]),
    );
    streakNotifier.value = status;
    return status;
  }

  bool _putDefaultIfMissing(Map<String, dynamic> map, String key, Object value) {
    if (!map.containsKey(key)) {
      map[key] = value;
      return true;
    }
    return false;
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
      final int expiryMillis = _asInt(value);
      if (expiryMillis > 0) {
        normalized[normalizedKey] = expiryMillis;
      }
    });
    return normalized;
  }

  bool _previewUnlockStateEquals(Object? raw, Map<String, int> normalized) {
    if (raw is! Map) {
      return normalized.isEmpty;
    }
    if (raw.length != normalized.length) {
      return false;
    }
    for (final entry in normalized.entries) {
      final Object? rawValue = raw[entry.key];
      if (_asInt(rawValue) != entry.value) {
        return false;
      }
    }
    for (final rawKey in raw.keys) {
      final String normalizedRawKey = _normalizeCollectionKey(rawKey.toString());
      if (!normalized.containsKey(normalizedRawKey)) {
        return false;
      }
    }
    return true;
  }

  bool _pruneExpiredPreviewUnlocks(Map<String, int> unlocks, {required int nowMillis}) {
    final int before = unlocks.length;
    unlocks.removeWhere((_, expiryMillis) => expiryMillis <= nowMillis);
    return unlocks.length != before;
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

  String _localDayKey(DateTime date) {
    final DateTime local = date.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
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
