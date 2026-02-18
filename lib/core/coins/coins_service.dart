import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
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

class AiGenerationReservationResult {
  const AiGenerationReservationResult({required this.mode, required this.mutation});

  final AiChargeMode mode;
  final CoinMutationResult mutation;

  bool get success => mode != AiChargeMode.insufficient && mutation.success;

  int get coinsSpent => mode == AiChargeMode.coinSpend && mutation.changed ? -mutation.delta : 0;
}

class CoinsService {
  CoinsService._();

  static final CoinsService instance = CoinsService._();

  static const String _coinStateField = 'coinState';
  static const String _pendingReferralInviterPrefKey = 'pendingReferralInviterId';
  static const Duration _deltaAnimationDuration = Duration(milliseconds: 1400);
  static const Duration _premiumPreviewAccessDuration = Duration(hours: 24);

  final ValueNotifier<int> balanceNotifier = ValueNotifier<int>(globals.prismUser.coins);
  final ValueNotifier<int> deltaNotifier = ValueNotifier<int>(0);

  int _deltaVersion = 0;

  String? get pendingReferralInviterId =>
      (main.prefs.get(_pendingReferralInviterPrefKey) as String?)?.trim().isNotEmpty == true
      ? (main.prefs.get(_pendingReferralInviterPrefKey) as String).trim()
      : null;

  Future<void> setPendingReferralInviterId(String inviterUserId) async {
    final String inviter = inviterUserId.trim();
    if (inviter.isEmpty) {
      return;
    }
    await main.prefs.put(_pendingReferralInviterPrefKey, inviter);
  }

  Future<void> clearPendingReferralInviterId() => main.prefs.delete(_pendingReferralInviterPrefKey);

  Future<void> bootstrapForCurrentUser() async {
    if (!_canMutateCoins()) {
      return;
    }
    final String userId = globals.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final int coins = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        final bool stateChanged = _ensureCoinStateDefaults(coinState);
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
  }

  Future<int> refreshBalance() async {
    if (!_canMutateCoins()) {
      return globals.prismUser.coins;
    }
    final String userId = globals.prismUser.id;
    final Map<String, dynamic>? userData = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'coins.refresh_balance',
    );
    if (userData == null) {
      return globals.prismUser.coins;
    }
    final int coins = _asInt(userData['coins']);
    _applyLocalBalance(coins, delta: 0);
    return coins;
  }

  Future<CoinMutationResult> award(
    CoinEarnAction action, {
    String sourceTag = 'coins.award',
    int? amountOverride,
    String? reason,
  }) async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final int amount = amountOverride ?? action.defaultAmount();
    if (amount <= 0) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'invalid_amount');
    }
    final String userId = globals.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final int previous = _asInt(data['coins']);
        final int current = previous + amount;
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);
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
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final int amount = amountOverride ?? action.cost();
    if (amount <= 0) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'invalid_amount');
    }

    final String userId = globals.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final bool isPremium = _asBool(data['premium']) || globals.prismUser.premium;
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);
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

  Future<AiGenerationReservationResult> reserveForAiGeneration({
    String sourceTag = 'coins.reserve.ai_generation',
  }) async {
    if (!_canMutateCoins()) {
      return AiGenerationReservationResult(
        mode: AiChargeMode.insufficient,
        mutation: CoinMutationResult.noChange(
          balance: globals.prismUser.coins,
          success: false,
          reason: 'not_logged_in',
        ),
      );
    }
    final String userId = globals.prismUser.id;
    final String today = _localDayKey(DateTime.now());
    final AiGenerationReservationResult result = await firestoreClient.runTransaction<AiGenerationReservationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return AiGenerationReservationResult(
            mode: AiChargeMode.insufficient,
            mutation: CoinMutationResult.noChange(
              balance: globals.prismUser.coins,
              success: false,
              reason: 'user_missing',
            ),
          );
        }
        final int previous = _asInt(data['coins']);
        final bool isPremium = _asBool(data['premium']) || globals.prismUser.premium;
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);

        if (!isPremium) {
          final int freeUsed = _asInt(coinState['aiFreeUsedTotal']);
          if (freeUsed < 3) {
            coinState['aiFreeUsedTotal'] = freeUsed + 1;
            tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
              'coins': previous,
              _coinStateField: coinState,
            });
            return AiGenerationReservationResult(
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
            return AiGenerationReservationResult(
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
          return AiGenerationReservationResult(
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
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        return AiGenerationReservationResult(
          mode: AiChargeMode.coinSpend,
          mutation: CoinMutationResult(
            success: true,
            changed: true,
            previousBalance: previous,
            currentBalance: current,
            delta: -CoinPolicy.aiGeneration,
            reason: 'ai_coin_spend_reserved',
          ),
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
    analytics.logEvent(
      name: 'ai_charge_reserved',
      parameters: <String, Object>{
        'mode': result.mode.value,
        'coinsSpent': result.coinsSpent,
        'balance': globals.prismUser.coins,
        'sourceTag': sourceTag,
      },
    );
    return result;
  }

  Future<CoinMutationResult> rollbackAiGenerationReservation(
    AiChargeMode mode, {
    String sourceTag = 'coins.rollback.ai_generation',
  }) async {
    if (mode == AiChargeMode.insufficient) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, reason: 'no_reservation_to_rollback');
    }

    if (mode == AiChargeMode.coinSpend) {
      final CoinMutationResult refund = await refundSpend(
        CoinSpendAction.aiGeneration,
        sourceTag: sourceTag,
        reason: 'ai_generation_failed_refund',
      );
      analytics.logEvent(
        name: 'ai_charge_rolled_back',
        parameters: <String, Object>{
          'mode': mode.value,
          'coinsRefunded': CoinPolicy.aiGeneration,
          'balance': globals.prismUser.coins,
          'sourceTag': sourceTag,
        },
      );
      return refund;
    }

    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String userId = globals.prismUser.id;
    final String today = _localDayKey(DateTime.now());
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);
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
    analytics.logEvent(
      name: 'ai_charge_rolled_back',
      parameters: <String, Object>{'mode': mode.value, 'balance': globals.prismUser.coins, 'sourceTag': sourceTag},
    );
    return result;
  }

  void commitAiGenerationReservation({
    required AiChargeMode mode,
    required int coinsSpent,
    String sourceTag = 'coins.commit.ai_generation',
  }) {
    analytics.logEvent(
      name: 'ai_charge_committed',
      parameters: <String, Object>{
        'mode': mode.value,
        'coinsSpent': coinsSpent,
        'balance': globals.prismUser.coins,
        'sourceTag': sourceTag,
      },
    );
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
    if (globals.prismUser.premium) {
      return true;
    }
    if (!_canMutateCoins()) {
      return false;
    }
    final String userId = globals.prismUser.id;
    final Map<String, dynamic>? userData = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'coins.preview.check',
    );
    if (userData == null) {
      return false;
    }
    final bool isPremium = _asBool(userData['premium']) || globals.prismUser.premium;
    if (isPremium) {
      return true;
    }
    final Map<String, dynamic> coinState = _coinStateFromRaw(userData[_coinStateField]);
    _ensureCoinStateDefaults(coinState);
    final Map<String, int> previewUnlocks = _previewUnlocksFromState(coinState);
    return (previewUnlocks[normalizedKey] ?? 0) > DateTime.now().millisecondsSinceEpoch;
  }

  Future<CoinMutationResult> unlockPremiumPreview24hForCollection({
    required String collectionKey,
    String sourceTag = 'coins.preview.unlock',
  }) async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String normalizedKey = _normalizeCollectionKey(collectionKey);
    if (normalizedKey.isEmpty) {
      return CoinMutationResult.noChange(
        balance: globals.prismUser.coins,
        success: false,
        reason: 'invalid_collection_key',
      );
    }
    final String userId = globals.prismUser.id;
    final int nowMillis = DateTime.now().millisecondsSinceEpoch;
    final int expiryMillis = nowMillis + _premiumPreviewAccessDuration.inMilliseconds;
    const int previewCost = CoinPolicy.premiumPreview24h;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final bool isPremium = _asBool(data['premium']) || globals.prismUser.premium;
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);
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
    }
    return result;
  }

  Future<CoinMutationResult> claimDailyLoginAndStreakIfEligible() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String userId = globals.prismUser.id;
    final String today = _localDayKey(DateTime.now());

    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);

        final String lastClaimDate = (coinState['lastDailyClaimDate'] as String? ?? '').trim();
        if (lastClaimDate == today) {
          return CoinMutationResult.noChange(balance: previous, reason: 'daily_already_claimed');
        }

        int streakDay = _asInt(coinState['streakDay']);
        if (lastClaimDate.isNotEmpty && _isPreviousDay(lastClaimDate, today)) {
          streakDay += 1;
        } else {
          streakDay = 1;
        }

        int reward = CoinPolicy.dailyLogin;
        if (streakDay >= 7) {
          reward += CoinPolicy.streak7Bonus;
          streakDay = 0;
        }

        final int current = previous + reward;
        coinState['lastDailyClaimDate'] = today;
        coinState['streakDay'] = streakDay;
        tx.updateDoc(FirebaseCollections.usersV2, userId, <String, dynamic>{
          'coins': current,
          _coinStateField: coinState,
        });
        return CoinMutationResult(
          success: true,
          changed: true,
          previousBalance: previous,
          currentBalance: current,
          delta: reward,
          reason: 'daily_login',
        );
      },
      sourceTag: 'coins.claim_daily_and_streak',
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );

    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logEarn(
        action: CoinEarnAction.dailyLogin,
        amount: CoinPolicy.dailyLogin,
        sourceTag: 'coins.claim_daily_and_streak',
      );
      if (result.delta > CoinPolicy.dailyLogin) {
        _logEarn(
          action: CoinEarnAction.streakBonus,
          amount: result.delta - CoinPolicy.dailyLogin,
          sourceTag: 'coins.claim_daily_and_streak',
        );
      }
    }
    return result;
  }

  Future<CoinMutationResult> maybeAwardProDailyBonus() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String userId = globals.prismUser.id;
    final String today = _localDayKey(DateTime.now());
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final bool isPremium = _asBool(data['premium']) || globals.prismUser.premium;
        final int previous = _asInt(data['coins']);
        if (!isPremium) {
          return CoinMutationResult.noChange(balance: previous, reason: 'not_premium');
        }
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);
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

    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      _logEarn(
        action: CoinEarnAction.proDailyBonus,
        amount: CoinPolicy.proDailyBonus,
        sourceTag: 'coins.claim_pro_daily_bonus',
      );
    }
    return result;
  }

  Future<CoinMutationResult> maybeAwardProfileCompletion() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    if (!_isProfileComplete()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, reason: 'profile_incomplete');
    }
    final String userId = globals.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);
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
    }
    return result;
  }

  Future<CoinMutationResult> maybeAwardFirstWallpaperUpload() async {
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String userId = globals.prismUser.id;
    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final int previous = _asInt(data['coins']);
        final Map<String, dynamic> coinState = _coinStateFromRaw(data[_coinStateField]);
        _ensureCoinStateDefaults(coinState);
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
    }
    return result;
  }

  Future<CoinMutationResult> processPendingReferralIfEligible({String? inviterUserId}) async {
    if (inviterUserId != null && inviterUserId.trim().isNotEmpty) {
      await setPendingReferralInviterId(inviterUserId);
    }
    if (!_canMutateCoins()) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'not_logged_in');
    }
    final String currentUserId = globals.prismUser.id;
    final String? pendingInviter = pendingReferralInviterId;
    if (pendingInviter == null || pendingInviter.isEmpty) {
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, reason: 'no_pending_referral');
    }
    if (pendingInviter == currentUserId) {
      await clearPendingReferralInviterId();
      return CoinMutationResult.noChange(balance: globals.prismUser.coins, reason: 'self_referral');
    }

    final CoinMutationResult result = await firestoreClient.runTransaction<CoinMutationResult>(
      (tx) async {
        final Map<String, dynamic>? currentData = await tx.getDoc(FirebaseCollections.usersV2, currentUserId);
        if (currentData == null) {
          return CoinMutationResult.noChange(balance: globals.prismUser.coins, success: false, reason: 'user_missing');
        }
        final int currentPrevious = _asInt(currentData['coins']);
        final Map<String, dynamic> currentState = _coinStateFromRaw(currentData[_coinStateField]);
        _ensureCoinStateDefaults(currentState);
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
        _ensureCoinStateDefaults(inviterState);

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
    }
    return result;
  }

  bool _canMutateCoins() {
    return globals.prismUser.loggedIn && globals.prismUser.id.trim().isNotEmpty;
  }

  bool _isProfileComplete() {
    final bool hasName = globals.prismUser.name.trim().isNotEmpty;
    final bool hasUsername = globals.prismUser.username.trim().isNotEmpty;
    final bool hasBio = globals.prismUser.bio.trim().isNotEmpty;
    final bool hasLink = globals.prismUser.links.values.any((value) => value.toString().trim().isNotEmpty);
    return hasName && hasUsername && hasBio && hasLink;
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

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final String normalized = (value?.toString() ?? '').toLowerCase().trim();
    return normalized == 'true' || normalized == '1';
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

  bool _ensureCoinStateDefaults(Map<String, dynamic> coinState) {
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
    final Map<String, int> normalizedPreviewUnlocks = _previewUnlocksFromState(coinState);
    if (!_previewUnlockStateEquals(coinState['premiumPreviewUnlocks'], normalizedPreviewUnlocks)) {
      coinState['premiumPreviewUnlocks'] = normalizedPreviewUnlocks;
      changed = true;
    }
    return changed;
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
    final int previous = globals.prismUser.coins;
    globals.prismUser.coins = newBalance;
    balanceNotifier.value = newBalance;
    if (delta == 0 && previous == newBalance) {
      return;
    }
    if (main.prefs.isOpen) {
      unawaited(main.prefs.put(main.userHiveKey, globals.prismUser));
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
    analytics.logEvent(
      name: 'coin_earned',
      parameters: <String, Object>{
        'action': action.name,
        'amount': amount,
        'balance': globals.prismUser.coins,
        'sourceTag': sourceTag,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  void _logSpend({required CoinSpendAction action, required int amount, required String sourceTag, String? reason}) {
    analytics.logEvent(
      name: 'coin_spent',
      parameters: <String, Object>{
        'action': action.name,
        'amount': amount,
        'balance': globals.prismUser.coins,
        'sourceTag': sourceTag,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  void logLowBalanceNudge({required String sourceTag, required int requiredCoins}) {
    analytics.logEvent(
      name: 'coin_low_balance_nudge_shown',
      parameters: <String, Object>{
        'sourceTag': sourceTag,
        'requiredCoins': requiredCoins,
        'balance': globals.prismUser.coins,
      },
    );
  }

  void logWatchAndDownloadUsed({required bool isPremiumContent, required String sourceTag}) {
    analytics.logEvent(
      name: 'coin_watch_and_download_used',
      parameters: <String, Object>{'isPremiumContent': isPremiumContent, 'sourceTag': sourceTag},
    );
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
