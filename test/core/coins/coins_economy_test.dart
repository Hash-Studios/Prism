import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

Map<String, Object?> _paid({
  int before = 100,
  int after = 70,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'success': true,
  'changed': true,
  'previousBalance': before,
  'currentBalance': after,
  'delta': after - before,
  'reason': 'ok',
  ...extra,
};

Map<String, Object?> _refused(String reason, {bool insufficient = false}) => <String, Object?>{
  'success': false,
  'changed': false,
  'previousBalance': 100,
  'currentBalance': 100,
  'delta': 0,
  'reason': reason,
  if (insufficient) 'insufficientBalance': true,
};

Map<String, Object?> _quests({bool chestOpened = false, int progress = 0}) => <String, Object?>{
  'dayKey': '2026-10-17',
  'items': <Map<String, Object?>>[
    <String, Object?>{'id': 'wotd_view', 'event': 'view_wotd', 'target': 1, 'progress': progress, 'claimed': false},
    <String, Object?>{'id': 'fav_3', 'event': 'favourite', 'target': 3, 'progress': 0, 'claimed': false},
    <String, Object?>{'id': 'future', 'event': 'unknown_event', 'target': 1, 'progress': 0, 'claimed': false},
  ],
  'bonus': <String, Object?>{'id': 'watch_ad', 'event': 'watch_ad', 'target': 1, 'progress': 0, 'claimed': false},
  'chestOpened': chestOpened,
  'chestDoubled': false,
  'weekKey': '2026-W42',
  'weekly': <String, Object?>{'id': 'weekly_set_5', 'event': 'set_wallpaper', 'target': 5, 'progress': 2},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService service = CoinsService.instance;
  final RegExp idPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
  late List<(String, Map<String, dynamic>)> calls;

  void reply(Object? Function(String name, Map<String, dynamic> params) answer) {
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      if (name == 'reconcileRankRewards') return <String, Object?>{};
      return answer(name, params);
    };
  }

  setUp(() async {
    calls = <(String, Map<String, dynamic>)>[];
    await backend.install();
    service.balanceNotifier.value = 100;
    reply((_, _) => _paid());
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await service.refreshStreakStatus();
    EconomyConfig.resetForTest();
    await getIt.reset();
  });

  group('bootstrap', () {
    test('reads the root doc and the private economy doc', () async {
      final CoinsTestFirestore firestore = CoinsTestFirestore()
        ..userData = <String, dynamic>{
          'coins': 40,
          'xp': 650,
          'xpWeek': <String, Object>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 90},
          'cosmetics': <String, Object>{'frame': 'frame_ring'},
          'coinState': <String, Object>{
            'adsToday': <String, Object>{'day': economyDayKey(DateTime.now()), 'count': 1},
          },
        }
        ..docs['usersv2/${backend.userId}/private/economy'] = <String, dynamic>{
          'rev': 4,
          'quests': _quests(),
          'inventory': <String, Object>{
            'owned': <String, int>{'frame_ring': 1, 'theme_rose': 2},
          },
          'drops': <String, Object>{
            'unlocked': <String, Object>{
              'W1': <String, String>{'weekKey': '2026-W41', 'url': 'https://x/w1.jpg'},
            },
          },
          'passes': <String, Object>{
            'premiumPassUntil': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
            'liveStyles': <String, int>{'aurora': DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch},
          },
          'graceDownloadsUsed': 1,
        };
      getIt.registerSingleton<FirestoreClient>(firestore);
      backend.onCall = (_, _) async => <String, Object>{};

      await service.bootstrapForCurrentUser();

      expect(service.balanceNotifier.value, 40);
      expect(service.xpNotifier.value.xp, 650);
      expect(service.xpNotifier.value.weekXp, 90);
      expect(service.xpNotifier.value.rank.id, 'silver');
      final QuestState quests = service.questsNotifier.value!;
      expect(quests.items.map((QuestItem q) => q.id), <String>['wotd_view', 'fav_3']);
      expect(quests.bonus?.event, QuestEvent.watchAd);
      expect(quests.weekly?.progress, 2);
      expect(service.inventoryNotifier.value.owned, <String>{'frame_ring', 'theme_rose'});
      expect(service.inventoryNotifier.value.frame, 'frame_ring');
      expect(service.dropsUnlockedNotifier.value['W1']?.url, 'https://x/w1.jpg');
      expect(service.passesNotifier.value.liveStyleActive('aurora', DateTime.now()), isTrue);
      expect(service.premiumContentUnlocked, isTrue);
      expect(service.autoRotateUnlocked, isFalse);
      expect(service.graceDownloadsLeft, 2);
      expect(service.adsRewardNow, CoinPolicy.rewardedAd);
      expect(await service.hasPremiumPreviewAccessForCollection('anything'), isTrue);
    });

    test('a week-old xpWeek counts as zero this week', () {
      final XpStatus xp = XpStatus.fromUserData(<String, dynamic>{
        'xp': 10,
        'xpWeek': <String, Object>{'weekKey': '2020-W01', 'xp': 99},
      });
      expect((xp.xp, xp.weekXp, xp.rank.id), (10, 0, 'bronze'));
    });
  });

  group('rewarded ad', () {
    test('first ad of the day pays the first-of-day amount, then the base amount', () async {
      expect(service.adsRewardNow, 20);
      reply((_, _) => _paid(after: 120, extra: <String, Object?>{'adsRemaining': 19}));
      await service.award(CoinEarnAction.rewardedAd);
      expect(service.adsRewardNow, 10);
    });

    test("a credited ad ticks today's watch_ad bonus quest and reconciles rank rewards", () async {
      final Map<String, Object?> today = <String, Object?>{..._quests(), 'dayKey': economyDayKey(DateTime.now())};
      reply((_, _) => <String, Object?>{'success': true, 'rev': 1, 'quests': today});
      await service.progressQuest(null);
      calls.clear();
      reply((_, _) => _paid(after: 120));
      await service.award(CoinEarnAction.rewardedAd);
      expect(service.questsNotifier.value?.bonus?.claimed, isTrue);
      expect(calls.map(((String, Map<String, dynamic>) c) => c.$1), <String>['awardCoins', 'reconcileRankRewards']);
    });
  });

  group('spend', () {
    test('every spend sends pricingVersion 2 and a live style id', () async {
      reply((_, _) => _paid(extra: <String, Object?>{'passUntil': DateTime.utc(2030).millisecondsSinceEpoch}));
      await service.spend(CoinSpendAction.liveWallpaperStyle, styleId: 'aurora');
      final Map<String, dynamic> params = calls.single.$2;
      expect(params['pricingVersion'], 2);
      expect(params['styleId'], 'aurora');
      expect(service.passesNotifier.value.liveStyles['aurora'], DateTime.utc(2030));
    });

    test('auto-rotate pass spend opens auto-rotate', () async {
      reply((_, _) => _paid(extra: <String, Object?>{'passUntil': DateTime.utc(2099).millisecondsSinceEpoch}));
      await service.spend(CoinSpendAction.autoRotatePass7d);
      expect(service.autoRotateUnlocked, isTrue);
    });

    test('a grace download updates the downloads left', () async {
      reply(
        (_, _) => <String, Object?>{
          'success': true,
          'changed': false,
          'bypassed': true,
          'currentBalance': 100,
          'reason': 'grace_download',
          'graceDownloadsLeft': 1,
        },
      );
      final CoinMutationResult result = await service.spend(CoinSpendAction.wallpaperDownload);
      expect(result.bypassed, isTrue);
      expect(service.graceDownloadsLeft, 1);
    });
  });

  group('claimProSpin', () {
    test('a win credits coins with no spin XP', () async {
      reply(
        (_, _) => _paid(
          after: 150,
          extra: <String, Object?>{
            'coins': 50,
            'segment': 2,
            'xpPolicyVersion': 1,
            'xp': 0,
            'xpAwarded': 0,
            'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 0},
          },
        ),
      );
      final ProSpinResult result = await service.claimProSpin();
      expect((result.outcome, result.coins, result.segment), (ProSpinOutcome.won, 50, 2));
      expect(service.balanceNotifier.value, 150);
      expect(service.xpNotifier.value.xp, 0);
      expect(calls.first.$2['requestId'], matches(idPattern));
      expect(calls.last.$1, 'reconcileRankRewards');
    });

    test('refusals map to outcomes', () async {
      reply((_, _) => _refused('pro_spin_already_claimed'));
      expect((await service.claimProSpin()).outcome, ProSpinOutcome.alreadyClaimed);
      reply((_, _) => _refused('pro_spin_requires_premium'));
      expect((await service.claimProSpin()).outcome, ProSpinOutcome.notPro);
    });

    test('a lost reply keeps the request id for the next try, a reply clears it', () async {
      backend.onCall = (String name, Map<String, dynamic> params) async {
        calls.add((name, params));
        if (calls.length == 1) throw FirebaseFunctionsException(code: 'unavailable', message: 'lost');
        return _paid(extra: <String, Object?>{'coins': 20, 'segment': 0});
      };
      expect((await service.claimProSpin()).outcome, ProSpinOutcome.failed);
      await service.claimProSpin();
      backend.onCall = (String name, Map<String, dynamic> params) async {
        calls.add((name, params));
        return _refused('pro_spin_already_claimed');
      };
      await service.claimProSpin();
      final List<String> ids = <String>[
        for (final (String name, Map<String, dynamic> params) in calls)
          if (name == 'claimProSpin') params['requestId'] as String,
      ];
      expect(ids, hasLength(3));
      expect(ids[0], ids[1]);
      expect(ids[2], isNot(ids[1]));
    });
  });

  group('progressQuest', () {
    test('client events are sent with an event id and awards land in the notifier', () async {
      reply(
        (_, _) => <String, Object?>{
          'success': true,
          'rev': 3,
          'quests': _quests(progress: 1),
          'awarded': <Map<String, Object>>[
            <String, Object>{'id': 'wotd_view', 'coins': 2, 'xp': 25},
          ],
          'currentBalance': 102,
          'delta': 2,
          'xpPolicyVersion': 1,
          'xp': 25,
          'xpAwarded': 25,
          'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 25},
        },
      );
      final QuestState? state = await service.progressQuest(QuestEvent.viewWotd);
      expect(calls.first.$1, 'progressQuest');
      expect(calls.first.$2['event'], 'view_wotd');
      expect(calls.first.$2['eventId'], matches(idPattern));
      expect(calls.last.$1, 'reconcileRankRewards');
      expect(state?.items.first.isDone, isTrue);
      expect(service.questAwardsNotifier.value.single.coins, 2);
      expect(service.xpNotifier.value.xp, 25);
      expect(service.balanceNotifier.value, 102);
      service.consumeQuestAwards();
      expect(service.questAwardsNotifier.value, isEmpty);
    });

    test('a reply with an older rev is ignored', () async {
      reply((_, _) => <String, Object?>{'success': true, 'rev': 5, 'quests': _quests(progress: 1)});
      await service.progressQuest(null);
      reply((_, _) => <String, Object?>{'success': true, 'rev': 4, 'quests': _quests()});
      await service.progressQuest(null);
      expect(service.questsNotifier.value?.items.first.progress, 1);
    });

    test('events the server counts are never sent', () async {
      service.reportQuestEvent(QuestEvent.download);
      service.reportQuestEvent(QuestEvent.watchAd);
      await service.progressQuest(QuestEvent.setWallpaper);
      await pumpEventQueue();
      expect(calls, isEmpty);
    });

    test('guests send nothing', () async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      service.reportQuestEvent(QuestEvent.viewTrending);
      await pumpEventQueue();
      expect(calls, isEmpty);
    });

    test('a failing call never throws', () async {
      backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'internal', message: 'x');
      expect(await service.progressQuest(QuestEvent.colourSearch), isNull);
    });
  });

  group('openQuestChest', () {
    test('opened adds coins and a cosmetic', () async {
      reply(
        (_, _) => _paid(
          after: 110,
          extra: <String, Object?>{
            'coins': 10,
            'doubled': true,
            'itemId': 'glow_ember',
            'quests': _quests(chestOpened: true),
          },
        ),
      );
      final ChestResult result = await service.openQuestChest();
      expect(
        (result.outcome, result.coins, result.doubled, result.itemId),
        (ChestOutcome.opened, 10, true, 'glow_ember'),
      );
      expect(service.inventoryNotifier.value.owns('glow_ember'), isTrue);
      expect(service.questsNotifier.value?.chestOpened, isTrue);
    });

    test('refusals map to outcomes', () async {
      reply((_, _) => _refused('quest_chest_locked'));
      expect((await service.openQuestChest()).outcome, ChestOutcome.locked);
      reply((_, _) => _refused('quest_chest_already_opened'));
      expect((await service.openQuestChest()).outcome, ChestOutcome.alreadyOpened);
    });
  });

  group('purchaseShopItem', () {
    test('purchased stores the owned list', () async {
      reply(
        (_, _) => _paid(
          after: 0,
          extra: <String, Object?>{
            'itemId': 'frame_ring',
            'owned': <String>['frame_ring', 'theme_rose'],
          },
        ),
      );
      final ShopPurchaseResult result = await service.purchaseShopItem('frame_ring');
      expect(result.outcome, ShopPurchaseOutcome.purchased);
      expect(result.owned, <String>{'frame_ring', 'theme_rose'});
      expect(calls.single.$2['itemId'], 'frame_ring');
      expect(service.balanceNotifier.value, 0);
    });

    test('refusals map to outcomes', () async {
      final Map<String, ShopPurchaseOutcome> cases = <String, ShopPurchaseOutcome>{
        'shop_item_owned': ShopPurchaseOutcome.owned,
        'shop_item_pro_only': ShopPurchaseOutcome.proOnly,
        'shop_item_rank_locked': ShopPurchaseOutcome.rankLocked,
        'shop_item_expired': ShopPurchaseOutcome.expired,
      };
      for (final MapEntry<String, ShopPurchaseOutcome> c in cases.entries) {
        reply((_, _) => _refused(c.key));
        expect((await service.purchaseShopItem('frame_gold')).outcome, c.value, reason: c.key);
      }
      reply((_, _) => _refused('shopItem_insufficient_balance', insufficient: true));
      expect((await service.purchaseShopItem('frame_gold')).outcome, ShopPurchaseOutcome.insufficient);
      backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'invalid-argument', message: 'x');
      expect((await service.purchaseShopItem('nope')).outcome, ShopPurchaseOutcome.failed);
    });

    test('a replayed purchase reuses its request id per item', () async {
      backend.onCall = (String name, Map<String, dynamic> params) {
        calls.add((name, params));
        return Future<dynamic>.error(FirebaseFunctionsException(code: 'deadline-exceeded', message: 'slow'));
      };
      await service.purchaseShopItem('frame_ring');
      await service.purchaseShopItem('frame_ring');
      await service.purchaseShopItem('glow_ocean');
      expect(calls[0].$2['requestId'], calls[1].$2['requestId']);
      expect(calls[2].$2['requestId'], isNot(calls[0].$2['requestId']));
    });
  });

  group('equipCosmetic', () {
    test('writes the slot and mirrors the reply', () async {
      reply(
        (_, _) => <String, Object?>{
          'success': true,
          'cosmetics': <String, Object?>{'frame': 'frame_ring', 'nameGlow': null},
        },
      );
      expect(await service.equipCosmetic(CosmeticSlot.frame, 'frame_ring'), isTrue);
      expect(calls.single.$2['slot'], 'frame');
      expect(service.inventoryNotifier.value.frame, 'frame_ring');
    });

    test('a refusal returns false', () async {
      backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'failed-precondition', message: 'x');
      expect(await service.equipCosmetic(CosmeticSlot.nameGlow, 'glow_aurora'), isFalse);
    });
  });

  group('unlockDrop', () {
    test('unlocked stores the urls', () async {
      reply(
        (_, _) => _paid(
          extra: <String, Object?>{
            'unlocked': <Map<String, String>>[
              <String, String>{'id': 'A', 'url': 'https://x/a.jpg'},
              <String, String>{'id': 'B', 'url': 'https://x/b.jpg'},
            ],
          },
        ),
      );
      final DropUnlockResult result = await service.unlockDrop(weekKey: '2026-W42');
      expect(result.outcome, DropUnlockOutcome.unlocked);
      expect(result.unlocked.map((DropUnlock u) => u.wallId), <String>['A', 'B']);
      expect(calls.single.$2['wallId'], isNull);
      expect(service.dropsUnlockedNotifier.value['B']?.weekKey, '2026-W42');
    });

    test('refusals map to outcomes', () async {
      reply((_, _) => <String, Object?>{..._refused('drop_wall_already_unlocked'), 'success': true});
      expect((await service.unlockDrop(weekKey: 'w', wallId: 'A')).outcome, DropUnlockOutcome.alreadyUnlocked);
      reply((_, _) => _refused('drop_not_live'));
      expect((await service.unlockDrop(weekKey: 'w', wallId: 'A')).outcome, DropUnlockOutcome.notLive);
      reply((_, _) => _refused('dropWall_insufficient_balance', insufficient: true));
      expect((await service.unlockDrop(weekKey: 'w', wallId: 'A')).outcome, DropUnlockOutcome.insufficient);
    });
  });

  group('boostWall', () {
    test('boosted returns the end time', () async {
      reply((_, _) => _paid(extra: <String, Object?>{'endsAt': DateTime.utc(2030).millisecondsSinceEpoch}));
      final BoostResult result = await service.boostWall('W1');
      expect((result.outcome, result.endsAt), (BoostOutcome.boosted, DateTime.utc(2030)));
    });

    test('refusals map to outcomes', () async {
      reply((_, _) => _refused('boost_active'));
      expect((await service.boostWall('W1')).outcome, BoostOutcome.active);
      reply((_, _) => _refused('boost_wall_not_approved'));
      expect((await service.boostWall('W1')).outcome, BoostOutcome.notApproved);
      reply(
        (_, _) => <String, Object?>{
          ..._refused('boost_slots_full'),
          'nextFreeAt': DateTime.utc(2031).millisecondsSinceEpoch,
        },
      );
      final BoostResult full = await service.boostWall('W1');
      expect((full.outcome, full.nextFreeAt), (BoostOutcome.slotsFull, DateTime.utc(2031)));
      backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'permission-denied', message: 'x');
      expect((await service.boostWall('W1')).outcome, BoostOutcome.notOwner);
    });
  });

  group('giftPremiumPass', () {
    test('sent returns the expiry', () async {
      reply((_, _) => _paid(extra: <String, Object?>{'expiresAt': DateTime.utc(2030).millisecondsSinceEpoch}));
      final GiftResult result = await service.giftPremiumPass('friend');
      expect((result.outcome, result.expiresAt), (GiftOutcome.sent, DateTime.utc(2030)));
      expect(calls.single.$2['recipientUid'], 'friend');
    });

    test('refusals map to outcomes', () async {
      final Map<String, GiftOutcome> cases = <String, GiftOutcome>{
        'gift_daily_limit': GiftOutcome.limit,
        'gift_recipient_daily_limit': GiftOutcome.limit,
        'gift_recipient_premium': GiftOutcome.recipientPremium,
        'gift_sender_too_new': GiftOutcome.senderTooNew,
        'gift_blocked': GiftOutcome.blocked,
      };
      for (final MapEntry<String, GiftOutcome> c in cases.entries) {
        reply((_, _) => _refused(c.key));
        expect((await service.giftPremiumPass('friend')).outcome, c.value, reason: c.key);
      }
      reply((_, _) => _refused('giftPremiumPass_insufficient_balance', insufficient: true));
      expect((await service.giftPremiumPass('friend')).outcome, GiftOutcome.insufficient);
      backend.onCall = (_, _) async => throw FirebaseFunctionsException(code: 'invalid-argument', message: 'self');
      expect((await service.giftPremiumPass('friend')).outcome, GiftOutcome.failed);
    });
  });

  group('buyDrawTicket', () {
    test('bought returns the ticket count', () async {
      reply(
        (_, _) => _paid(
          extra: <String, Object?>{
            'tickets': 2,
            'weekKey': '2026-W42',
            'closesAt': DateTime.utc(2026, 10, 19).millisecondsSinceEpoch,
          },
        ),
      );
      final DrawTicketResult result = await service.buyDrawTicket();
      expect((result.outcome, result.tickets, result.weekKey), (DrawTicketOutcome.bought, 2, '2026-W42'));
      expect(result.closesAt, DateTime.utc(2026, 10, 19));
    });

    test('refusals map to outcomes', () async {
      final Map<String, DrawTicketOutcome> cases = <String, DrawTicketOutcome>{
        'draw_ticket_limit': DrawTicketOutcome.limit,
        'draw_disabled': DrawTicketOutcome.disabled,
        'draw_closed': DrawTicketOutcome.closed,
        'draw_pro_not_eligible': DrawTicketOutcome.proNotEligible,
      };
      for (final MapEntry<String, DrawTicketOutcome> c in cases.entries) {
        reply((_, _) => _refused(c.key));
        expect((await service.buyDrawTicket()).outcome, c.value, reason: c.key);
      }
      reply((_, _) => _refused('drawTicket_insufficient_balance', insufficient: true));
      expect((await service.buyDrawTicket()).outcome, DrawTicketOutcome.insufficient);
    });
  });

  test('signed-out calls fail without a request', () async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    expect((await service.claimProSpin()).outcome, ProSpinOutcome.failed);
    expect((await service.purchaseShopItem('frame_ring')).outcome, ShopPurchaseOutcome.failed);
    expect((await service.buyDrawTicket()).outcome, DrawTicketOutcome.failed);
    expect(calls, isEmpty);
  });
}
