import 'dart:math';

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/features/promo_codes/domain/entities/promo_code.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;

typedef PromoCallable = Future<Object?> Function(String name, Map<String, Object?> data);

/// Mirrors the server's CODE_PATTERN in functions/src/promoCodes.ts, so a typo never spends a rate-limited attempt.
final RegExp _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{10,32}$');

String normalizePromoCode(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

bool isPromoCodeShape(String normalized) => _codePattern.hasMatch(normalized);

String newPromoRequestId() {
  final Random random = Random.secure();
  return List<String>.generate(24, (_) => random.nextInt(36).toRadixString(36)).join();
}

PromoReward? _rewardFrom(Object? raw, Object? premiumUntilMs) {
  if (raw is! Map) return null;
  final Object? amount = raw['type'] == 'coins' ? raw['coins'] : raw['days'];
  if (amount is! int) return null;
  return switch (raw['type']) {
    'coins' => CoinsReward(amount),
    'premiumDays' => PremiumDaysReward(
      amount,
      until: premiumUntilMs is int ? DateTime.fromMillisecondsSinceEpoch(premiumUntilMs) : null,
    ),
    _ => null,
  };
}

class PromoCodeSummary {
  const PromoCodeSummary({
    required this.code,
    required this.label,
    required this.reward,
    required this.maxRedemptions,
    required this.redemptionCount,
    required this.expiresAt,
    required this.minAccountAgeDays,
    required this.newUsersOnlyDays,
    required this.disabled,
  });

  final String code;
  final String label;
  final PromoReward reward;
  final int maxRedemptions;
  final int redemptionCount;
  final DateTime expiresAt;
  final int minAccountAgeDays;
  final int? newUsersOnlyDays;
  final bool disabled;

  static PromoCodeSummary? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final PromoReward? reward = _rewardFrom(raw['reward'], null);
    final Object? expiresAtMs = raw['expiresAtMs'];
    if (reward == null || raw['code'] is! String || expiresAtMs is! int) return null;
    return PromoCodeSummary(
      code: raw['code'] as String,
      label: raw['label'] is String ? raw['label'] as String : '',
      reward: reward,
      maxRedemptions: raw['maxRedemptions'] is int ? raw['maxRedemptions'] as int : 0,
      redemptionCount: raw['redemptionCount'] is int ? raw['redemptionCount'] as int : 0,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      minAccountAgeDays: raw['minAccountAgeDays'] is int ? raw['minAccountAgeDays'] as int : 0,
      newUsersOnlyDays: raw['newUsersOnlyDays'] is int ? raw['newUsersOnlyDays'] as int : null,
      disabled: raw['disabled'] == true,
    );
  }
}

class NewPromoCode {
  const NewPromoCode({
    required this.type,
    required this.amount,
    required this.maxRedemptions,
    required this.expiresAt,
    this.code,
    this.minAccountAgeDays = 0,
    this.newUsersOnlyDays,
    this.label = '',
  });

  final PromoRewardType type;
  final int amount;
  final int maxRedemptions;
  final DateTime expiresAt;
  final String? code;
  final int minAccountAgeDays;
  final int? newUsersOnlyDays;
  final String label;

  Map<String, Object?> toCallable() => <String, Object?>{
    'type': type == PromoRewardType.coins ? 'coins' : 'premiumDays',
    'amount': amount,
    'maxRedemptions': maxRedemptions,
    'expiresAtMs': expiresAt.millisecondsSinceEpoch,
    if (code != null && code!.isNotEmpty) 'code': code,
    'minAccountAgeDays': minAccountAgeDays,
    'newUsersOnlyDays': newUsersOnlyDays,
    'label': label,
  };
}

/// The redeemCode callable and the admin promo code callables. Codes never pass through Firestore on the client.
class PromoCodeRepository {
  PromoCodeRepository({PromoCallable? call}) : _call = call ?? _callable;

  final PromoCallable _call;

  static Future<Object?> _callable(String name, Map<String, Object?> data) async =>
      (await appFunctions
              .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: const Duration(seconds: 20)))
              .call<Object?>(data))
          .data;

  /// Reuse one [requestId] for retries of the same attempt; the server then returns the first result again.
  Future<RedeemOutcome> redeem(
    String normalizedCode, {
    required String requestId,
    required StoreCodePlatform platform,
  }) async {
    final Object? reply;
    try {
      reply = await _call('redeemCode', <String, Object?>{
        'code': normalizedCode,
        'requestId': requestId,
        'platform': platform.wireValue,
      });
    } on cf.FirebaseFunctionsException catch (error) {
      logger.w('redeemCode failed.', error: error.code);
      return RedeemFailed(switch (error.code) {
        'unauthenticated' => RedeemFailureReason.signedOut,
        'unavailable' || 'deadline-exceeded' => RedeemFailureReason.network,
        _ => RedeemFailureReason.unknown,
      });
    } catch (error) {
      logger.w('redeemCode failed.', error: error.runtimeType);
      return const RedeemFailed(RedeemFailureReason.network);
    }
    if (reply is! Map) return const RedeemFailed(RedeemFailureReason.unknown);
    if (reply['ok'] != true) return RedeemFailed(RedeemFailureReason.fromWire(reply['reason']));
    final PromoReward? reward = _rewardFrom(reply['reward'], reply['premiumUntil']);
    if (reward == null) return const RedeemFailed(RedeemFailureReason.unknown);
    return RedeemSucceeded(reward, coinBalance: reply['coinBalance'] is int ? reply['coinBalance'] as int : null);
  }

  Future<List<PromoCodeSummary>> listCodes() async {
    final Object? reply = await _call('listPromoCodes', const <String, Object?>{});
    final Object? codes = reply is Map ? reply['codes'] : null;
    if (codes is! List) return const <PromoCodeSummary>[];
    return codes.map(PromoCodeSummary.fromMap).whereType<PromoCodeSummary>().toList(growable: false);
  }

  /// Returns the stored code. Throws [cf.FirebaseFunctionsException] with the server's message on a bad field.
  Future<String> createCode(NewPromoCode code) async {
    final Object? reply = await _call('createPromoCode', code.toCallable());
    final Object? stored = reply is Map ? reply['code'] : null;
    if (stored is! String) throw StateError('createPromoCode returned no code.');
    return stored;
  }

  Future<void> setDisabled(String code, {required bool disabled}) =>
      _call('setPromoCodeDisabled', <String, Object?>{'code': code, 'disabled': disabled});
}
