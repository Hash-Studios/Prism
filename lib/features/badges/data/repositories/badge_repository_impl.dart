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
  final Map<String, Future<Result<List<Badge>>>> _inFlight = <String, Future<Result<List<Badge>>>>{};
  final Set<String> _handledNewBadgeIds = <String>{};
  String _queueOwner = '';

  @override
  ValueListenable<List<EarnedBadge>> get unseen {
    _setQueueOwner(_currentQueueOwner);
    return _unseen;
  }

  @override
  Future<Result<List<Badge>>> check() {
    final String uid = app_state.prismUser.id.trim();
    final Future<Result<List<Badge>>>? running = _inFlight[uid];
    if (running != null) return running;
    late final Future<Result<List<Badge>>> started;
    started = _check(uid).whenComplete(() {
      if (identical(_inFlight[uid], started)) _inFlight.remove(uid);
    });
    _inFlight[uid] = started;
    return started;
  }

  @override
  void markSeen(String id) {
    _setQueueOwner(_currentQueueOwner);
    _unseen.value = _unseen.value.where((EarnedBadge b) => b.id != id).toList(growable: false);
  }

  Future<Result<List<Badge>>> _check(String uid) async {
    if (!app_state.prismUser.loggedIn || uid.isEmpty) {
      return Result.error(const ServerFailure('Sign in to earn badges'));
    }
    final int startingBalance = app_state.prismUser.coins;
    final ValueNotifier<int> balanceNotifier = CoinsService.instance.balanceNotifier;
    bool balanceChanged = false;
    void onBalanceChanged() => balanceChanged = true;
    balanceNotifier.addListener(onBalanceChanged);
    _setQueueOwner(uid);
    try {
      final cf.HttpsCallableResult<dynamic> response = await appFunctions
          .httpsCallable('checkBadges', options: cf.HttpsCallableOptions(timeout: _callableTimeout))
          .call(<String, dynamic>{});
      if (!app_state.prismUser.loggedIn || uid != app_state.prismUser.id.trim()) {
        return Result.error(const ServerFailure('Session changed'));
      }
      final Map<Object?, Object?> data = response.data is Map ? response.data as Map<Object?, Object?> : const {};
      if (data['badges'] is! List || data['newBadges'] is! List || data['currentBalance'] is! num) {
        return Result.error(const ServerFailure('Invalid badge response'));
      }
      final int currentBalance = (data['currentBalance']! as num).toInt();
      if (balanceChanged || startingBalance != app_state.prismUser.coins) {
        try {
          await CoinsService.instance.refreshBalance();
        } catch (error, stackTrace) {
          CoinsService.instance.logCoinError(
            sourceTag: 'coins.badges.balance_refresh',
            error: error,
            stackTrace: stackTrace,
          );
        }
        if (!app_state.prismUser.loggedIn || uid != app_state.prismUser.id.trim()) {
          return Result.error(const ServerFailure('Session changed'));
        }
      } else {
        CoinsService.instance.applyServerBalance(currentBalance);
      }
      final List<Badge> badges = _parseBadges(data['badges']);
      app_state.prismUser.badges = badges;
      app_state.persistPrismUser();
      _setQueueOwner(uid);
      final List<EarnedBadge> added = <EarnedBadge>[];
      for (final EarnedBadge badge in _parseNew(data['newBadges'])) {
        if (_handledNewBadgeIds.add(badge.id)) added.add(badge);
      }
      if (added.isNotEmpty) {
        _unseen.value = <EarnedBadge>[..._unseen.value, ...added];
      }
      for (final EarnedBadge b in added) {
        analytics.track(BadgeEarnedEvent(badgeId: b.id, coins: b.coins));
      }
      return Result.success(badges);
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure('Failed to check badges: ${e.message ?? e.code}'));
    } catch (e) {
      return Result.error(ServerFailure('Failed to check badges: $e'));
    } finally {
      balanceNotifier.removeListener(onBalanceChanged);
    }
  }

  String get _currentQueueOwner => app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';

  void _setQueueOwner(String uid) {
    if (_queueOwner == uid) return;
    _queueOwner = uid;
    _unseen.value = const <EarnedBadge>[];
    _handledNewBadgeIds.clear();
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
