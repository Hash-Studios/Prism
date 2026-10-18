import 'package:Prism/core/coins/coins_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an old backend payload gets safe defaults', () {
    final r = StreakClaimResult.fromPayload(<String, dynamic>{
      'claimed': true,
      'streakDay': 7,
      'dailyReward': 15,
      'totalReward': 55,
      'newBalance': 100,
    });
    expect(r.claimed, isTrue);
    expect(r.streakCount, 7);
    expect(r.previousStreakCount, 6);
    expect(r.streakBest, 7);
    expect(r.streakBroken, isFalse);
    expect(r.freezesUsed, 0);
    expect(r.freezesLeft, 0);
    expect(r.isWeekComplete, isTrue);
    expect(r.milestone, isNull);
    expect(r.isChest, isFalse);
  });

  test('isChest is read from the payload', () {
    expect(StreakClaimResult.fromPayload(<String, dynamic>{'isChest': true}).isChest, isTrue);
    expect(StreakClaimResult.fromPayload(<String, dynamic>{'isChest': false, 'streakDay': 7}).isChest, isFalse);
  });

  test('a new backend payload is read as sent', () {
    final r = StreakClaimResult.fromPayload(<String, dynamic>{
      'claimed': true,
      'alreadyClaimedToday': false,
      'streakDay': 2,
      'streakCount': 30,
      'previousStreakCount': 28,
      'streakBest': 45,
      'streakBroken': false,
      'freezesUsed': 1,
      'freezesLeft': 1,
      'isWeekComplete': false,
      'milestone': 30,
    });
    expect(r.streakCount, 30);
    expect(r.previousStreakCount, 28);
    expect(r.streakBest, 45);
    expect(r.freezesUsed, 1);
    expect(r.freezesLeft, 1);
    expect(r.isWeekComplete, isFalse);
    expect(r.milestone, 30);
  });

  test('an empty payload is not a claim and never goes negative', () {
    final r = StreakClaimResult.fromPayload(<String, dynamic>{});
    expect(r.claimed, isFalse);
    expect(r.streakCount, 0);
    expect(r.previousStreakCount, 0);
    expect(r.lifecycleEvents, isEmpty);
  });

  test('milestones come from server awards rather than weekly arithmetic', () {
    final weekly = StreakClaimResult.fromPayload(<String, dynamic>{'claimed': true, 'streakCount': 7});
    expect(weekly.lifecycleEvents.map((event) => event.action), <String>['increment']);
    final awarded = StreakClaimResult.fromPayload(<String, dynamic>{
      'claimed': true,
      'streakCount': 30,
      'milestone': 30,
      'freezesUsed': 1,
      'freezesLeft': 1,
    });
    expect(awarded.lifecycleEvents.map((event) => event.action), <String>['increment', 'freeze_used', 'milestone']);
    expect(awarded.lifecycleEvents.last.milestone, 30);
  });

  test('a server-confirmed break emits the prior count then a new start', () {
    final result = StreakClaimResult.fromPayload(<String, dynamic>{
      'claimed': true,
      'streakCount': 1,
      'previousStreakCount': 40,
      'streakBroken': true,
    });
    expect(result.lifecycleEvents.map((event) => event.action), <String>['break', 'start']);
    expect(result.lifecycleEvents.first.previousCount, 40);
  });
}
