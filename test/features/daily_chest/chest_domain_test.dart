import 'dart:ui';

import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/daily_chest/domain/chest_accent.dart';
import 'package:Prism/features/daily_chest/domain/chest_action.dart';
import 'package:Prism/features/daily_chest/domain/chest_copy.dart';
import 'package:Prism/features/daily_chest/domain/chest_odds.dart';
import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:Prism/features/daily_chest/domain/chest_tiers.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:flutter_test/flutter_test.dart';

DailyChestStatus _status({bool opened = false, int questsLeft = 2, int price = 8}) =>
    DailyChestStatus(opened: opened, questsLeft: questsLeft, price: price);

void main() {
  group('the phase table', () {
    test('every phase has a marker and the spans run on from one to the next', () {
      final List<ChestMarker> markers = <ChestMarker>[
        for (final ChestPhase phase in ChestPhase.values) chestMarkers[phase]!,
      ];
      expect(markers.map((ChestMarker m) => m.name), <String>['idle', 'charge', 'open', 'opened', 'spent']);
      for (int i = 1; i < markers.length; i++) {
        expect(markers[i].startFrame, markers[i - 1].endFrame, reason: '${markers[i].name} starts where it should');
      }
      expect(markers.last.endFrame, chestTotalFrames - 1, reason: 'the file ends one frame after the last marker');
    });

    test('charge and idle loop, open plays once, spent holds', () {
      expect(
        <ChestPlayback>[for (final ChestPhase phase in ChestPhase.values) chestMarkers[phase]!.playback],
        <ChestPlayback>[
          ChestPlayback.loop,
          ChestPlayback.loop,
          ChestPlayback.once,
          ChestPlayback.loop,
          ChestPlayback.hold,
        ],
      );
    });

    test('only the open span has a burst frame, and it sits inside the span', () {
      final ChestMarker open = chestMarkers[ChestPhase.opening]!;
      expect(open.burstFrame, inInclusiveRange(open.startFrame, open.endFrame));
      expect(
        chestMarkers.entries.where((e) => e.key != ChestPhase.opening).every((e) => e.value.burstFrame == null),
        isTrue,
      );
    });

    test('a still box shows the first frame of the span it stands for, and the emptied box when spent', () {
      int stillFrame(ChestPhase phase) => chestMarkers[chestStillPhase(phase)]!.stillFrame;

      expect(stillFrame(ChestPhase.ready), 0);
      expect(stillFrame(ChestPhase.charging), 0);
      expect(stillFrame(ChestPhase.opening), 270);
      expect(stillFrame(ChestPhase.revealed), 270);
      expect(stillFrame(ChestPhase.spent), 392, reason: 'the file holds the emptied box from frame 391');
    });
  });

  group('chestAction', () {
    test('an opened chest is spent, whatever the balance', () {
      expect(chestAction(status: _status(opened: true), balance: 500), ChestAction.spent);
    });

    test('a free chest opens with no coins at all', () {
      expect(chestAction(status: _status(questsLeft: 0), balance: 0), ChestAction.open);
    });

    test('a paid chest opens when the balance covers the price and not when it is a coin short', () {
      expect(chestAction(status: _status(), balance: 8), ChestAction.open);
      expect(chestAction(status: _status(), balance: 7), ChestAction.getCoins);
    });
  });

  group('tiers', () {
    test('each tier has its game colour and a label', () {
      expect(
        <int>[for (final ChestTier t in ChestTier.values) t.color.toARGB32()],
        <int>[0xFF34D399, 0xFF38BDF8, 0xFFA78BFA, 0xFFF5B83D],
      );
      expect(
        <String>[for (final ChestTier t in ChestTier.values) t.label],
        <String>['Common', 'Rare', 'Epic', 'Legendary'],
      );
    });
  });

  group('odds by tier', () {
    test('the default table groups into the tiers the spec lists, with their share', () {
      final List<ChestOddsGroup> groups = chestOddsByTier(defaultChest);

      expect(groups.map((ChestOddsGroup g) => g.tier), ChestTier.values);
      expect(groups.map((ChestOddsGroup g) => g.rows.length), <int>[2, 2, 2, 1]);
      expect(groups.map((ChestOddsGroup g) => g.percent.round()), <int>[62, 26, 11, 1]);
      final CoinsPrize legendary = groups.last.rows.single.prize as CoinsPrize;
      expect(legendary.coins, 100);
      expect(groups[2].rows.map((WheelOdds o) => o.prize.runtimeType), <Type>[CosmeticPrize, CoinsPrize]);
    });

    test('a tier with no slot is left out and the rows of a tier keep the table order', () {
      const List<WheelSegment> table = <WheelSegment>[
        WheelSegment(CoinsPrize(7), weight: 30),
        WheelSegment(CoinsPrize(9), weight: 60),
        WheelSegment(CosmeticPrize(fallbackCoins: 15), weight: 10),
      ];
      final List<ChestOddsGroup> groups = chestOddsByTier(table);

      expect(groups.map((ChestOddsGroup g) => g.tier), <ChestTier>[ChestTier.common, ChestTier.rare]);
      expect(groups.first.rows.map((WheelOdds o) => (o.prize as CoinsPrize).coins), <int>[7, 9]);
      expect(groups.first.percent, closeTo(90, 1e-9));
    });
  });

  group('copy', () {
    test('the reset label counts to the next UTC midnight', () {
      expect(chestResetIn(DateTime.utc(2026, 10, 18, 18, 48)), '5h 12m');
      expect(chestResetIn(DateTime.utc(2026, 10, 18, 22)), '2h');
      expect(chestResetIn(DateTime.utc(2026, 10, 18, 23, 20)), '40m');
      expect(chestResetIn(DateTime.utc(2026, 10, 18, 23, 59, 30)), '1m');
      expect(chestResetIn(DateTime.utc(2026, 10, 31, 12)), '12h');
    });

    test('the reset label reads a local time as UTC', () {
      final DateTime local = DateTime.parse('2026-10-18T18:48:00-05:00');
      expect(chestResetIn(local), '12m');
    });

    test('the cost line says what the chest costs now', () {
      final DateTime now = DateTime.utc(2026, 10, 18, 18, 48);
      expect(chestCostLine(_status(questsLeft: 0), now: now), 'Your quests made it free today.');
      expect(chestCostLine(_status(), now: now), 'Open it for 8 coins, or finish 2 more quests to open it free.');
      expect(
        chestCostLine(_status(questsLeft: 1), now: now),
        'Open it for 8 coins, or finish 1 more quest to open it free.',
      );
      expect(chestCostLine(_status(opened: true), now: now), 'Opened. A new chest in 5h 12m.');
    });

    test('the bonus line says whether the chest doubles', () {
      expect(chestBonusLine(bonusDone: true), 'Bonus quest done: your coins are doubled.');
      expect(chestBonusLine(bonusDone: false), "Do today's bonus quest first to double your coins.");
    });

    test('the row subtitle follows the state', () {
      expect(chestRowSubtitle(_status(opened: true)), 'Opened. A new one tomorrow.');
      expect(chestRowSubtitle(_status(questsLeft: 0)), 'Free today');
      expect(chestRowSubtitle(_status(questsLeft: 3)), '8 coins, or free after 3 more quests');
      expect(chestRowSubtitle(_status(questsLeft: 1)), '8 coins, or free after 1 more quest');
      expect(chestRowSubtitle(_status(opened: true), doubled: true), 'Opened and doubled. A new one tomorrow.');
      expect(chestRowSubtitle(_status(questsLeft: 3), doubled: true), '8 coins, or free after 3 more quests');
    });
  });

  group('accent shades', () {
    test('a vivid accent gives a lighter and a darker shade of itself', () {
      const Color pink = Color(0xFFE91E63);
      final ChestAccent accent = chestAccentOf(pink)!;

      expect(accent.mid, pink);
      expect(accent.light.toARGB32(), Color.lerp(pink, const Color(0xFFFFFFFF), 0.35)!.toARGB32());
      expect(accent.dark.toARGB32(), Color.lerp(pink, const Color(0xFF000000), 0.35)!.toARGB32());
      expect(accent.light.computeLuminance(), greaterThan(pink.computeLuminance()));
      expect(accent.dark.computeLuminance(), lessThan(pink.computeLuminance()));
    });

    test('a grey accent gives none, so the box keeps its own purple', () {
      expect(chestAccentOf(const Color(0xFFFFFFFF)), isNull);
      expect(chestAccentOf(const Color(0xFF808080)), isNull);
      expect(chestAccentOf(const Color(0xFF8A7F86)), isNull);
    });
  });
}
