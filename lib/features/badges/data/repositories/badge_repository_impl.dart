import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BadgeRepository)
class BadgeRepositoryImpl implements BadgeRepository {
  BadgeRepositoryImpl();

  static const Duration _callableTimeout = Duration(seconds: 20);

  final ValueNotifier<List<EarnedBadge>> _unseen = ValueNotifier<List<EarnedBadge>>(const <EarnedBadge>[]);
  Future<Result<List<Badge>>>? _inFlight;
  String _queueOwner = '';

  @override
  ValueListenable<List<EarnedBadge>> get unseen => _unseen;

  @override
  Future<Result<List<Badge>>> check() {
    final Future<Result<List<Badge>>>? running = _inFlight;
    if (running != null) return running;
    final Future<Result<List<Badge>>> started = _check().whenComplete(() => _inFlight = null);
    _inFlight = started;
    return started;
  }

  @override
  void markSeen(String id) {
    _unseen.value = _unseen.value.where((EarnedBadge b) => b.id != id).toList(growable: false);
  }

  Future<Result<List<Badge>>> _check() async {
    final String uid = app_state.prismUser.id.trim();
    if (!app_state.prismUser.loggedIn || uid.isEmpty) {
      return Result.error(const ServerFailure('Sign in to earn badges'));
    }
    if (_queueOwner != uid) {
      _queueOwner = uid;
      _unseen.value = const <EarnedBadge>[];
    }
    try {
      final cf.HttpsCallableResult<dynamic> response = await appFunctions
          .httpsCallable('checkBadges', options: cf.HttpsCallableOptions(timeout: _callableTimeout))
          .call(<String, dynamic>{});
      if (uid != app_state.prismUser.id.trim()) {
        return Result.error(const ServerFailure('Session changed'));
      }
      final Map<Object?, Object?> data = response.data is Map ? response.data as Map<Object?, Object?> : const {};
      final List<Badge> badges = _parseBadges(data['badges']);
      app_state.prismUser.badges = badges;
      app_state.persistPrismUser();
      final Object? balance = data['currentBalance'];
      if (balance is num) CoinsService.instance.applyServerBalance(balance.toInt());
      final Set<String> queued = _unseen.value.map((EarnedBadge b) => b.id).toSet();
      final List<EarnedBadge> added = _parseNew(data['newBadges']).where((b) => !queued.contains(b.id)).toList();
      if (added.isNotEmpty) _unseen.value = <EarnedBadge>[..._unseen.value, ...added];
      for (final EarnedBadge b in added) {
        analytics.track(BadgeEarnedEvent(badgeId: b.id, coins: b.coins));
      }
      return Result.success(badges);
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure('Failed to check badges: ${e.message ?? e.code}'));
    } catch (e) {
      return Result.error(ServerFailure('Failed to check badges: $e'));
    }
  }

  static List<Badge> _parseBadges(Object? raw) {
    if (raw is! List) return const <Badge>[];
    final List<Badge> out = <Badge>[];
    for (final Object? row in raw) {
      if (row is! Map) continue;
      String text(String key) => row[key]?.toString() ?? '';
      final String id = text('id');
      if (id.isEmpty) continue;
      out.add(
        Badge(
          id: id,
          name: text('name'),
          description: text('description'),
          awardedAt: text('awardedAt'),
          imageUrl: text('imageUrl'),
          color: text('color'),
          url: text('url'),
        ),
      );
    }
    return out;
  }

  static List<EarnedBadge> _parseNew(Object? raw) {
    if (raw is! List) return const <EarnedBadge>[];
    return <EarnedBadge>[
      for (final Object? row in raw)
        if (row is Map && (row['id']?.toString() ?? '').isNotEmpty)
          EarnedBadge(id: row['id'].toString(), coins: row['coins'] is num ? (row['coins'] as num).toInt() : 0),
    ];
  }
}
