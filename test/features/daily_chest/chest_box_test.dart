import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/features/daily_chest/domain/chest_accent.dart';
import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:Prism/features/daily_chest/domain/chest_tiers.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

const double _frames = 393;

void main() {
  /// A box on a theme with [primary] as the accent. The real file loads on the first frame and has the contract's
  /// frames: 60 fps, `open` from frame 180 to 270. `chest_asset_load_test.dart` covers a file that arrives late.
  Future<void> pumpBox(
    WidgetTester tester, {
    required ChestPhase phase,
    Color? glow,
    bool still = false,
    bool reduceMotion = false,
    Color primary = const Color(0xFFE91E63),
    VoidCallback? onBurst,
    VoidCallback? onOpened,
  }) {
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(primary: primary),
          ),
          home: Center(
            child: ChestBox(phase: phase, glow: glow, still: still, size: 200, onBurst: onBurst, onOpened: onOpened),
          ),
        ),
      ),
    );
  }

  LottieBuilder lottie(WidgetTester tester) => tester.widget<LottieBuilder>(find.byType(LottieBuilder));

  double progress(WidgetTester tester) => lottie(tester).controller!.value;

  group('playing', () {
    testWidgets('idle loops inside its span and never leaves it', (tester) async {
      await pumpBox(tester, phase: ChestPhase.ready);
      final List<double> seen = <double>[];
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        seen.add(progress(tester));
      }

      expect(seen.every((double p) => p >= 0 && p <= 120 / _frames + 1e-3), isTrue);
      expect(seen.toSet().length, greaterThan(10), reason: 'it keeps moving');
      // 4 s is two loops of 2 s: it came back down at least once.
      expect(seen.indexed.any((e) => e.$1 > 0 && e.$2 < seen[e.$1 - 1]), isTrue);
    });

    testWidgets('a phase change jumps to the start of the new span', (tester) async {
      await pumpBox(tester, phase: ChestPhase.ready);
      await tester.pump(const Duration(milliseconds: 700));
      await pumpBox(tester, phase: ChestPhase.charging);

      expect(progress(tester), closeTo(120 / _frames, 1e-3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(progress(tester), inInclusiveRange(120 / _frames, 180 / _frames));
    });

    testWidgets('open plays once: the burst comes 16 frames in, then it ends and holds its last frame', (tester) async {
      int bursts = 0;
      int opened = 0;
      await pumpBox(tester, phase: ChestPhase.charging);
      await pumpBox(tester, phase: ChestPhase.opening, onBurst: () => bursts++, onOpened: () => opened++);

      await tester.pump(const Duration(milliseconds: 200));
      expect((bursts, opened), (0, 0), reason: '200 ms is frame 192');
      await tester.pump(const Duration(milliseconds: 100));
      expect((bursts, opened), (1, 0), reason: '300 ms is frame 198');
      await tester.pump(const Duration(milliseconds: 1100));
      expect((bursts, opened), (1, 0), reason: '1400 ms is frame 264');
      await tester.pump(const Duration(milliseconds: 200));
      expect((bursts, opened), (1, 1));
      expect(progress(tester), closeTo(270 / _frames, 1e-3));
      await tester.pump(const Duration(seconds: 2));
      expect((bursts, opened), (1, 1), reason: 'it does not play again');
    });

    testWidgets('opened loops after the open', (tester) async {
      await pumpBox(tester, phase: ChestPhase.revealed);
      await tester.pump(const Duration(milliseconds: 500));

      expect(progress(tester), inInclusiveRange(270 / _frames, 390 / _frames));
      expect(progress(tester), greaterThan(270 / _frames));
    });

    testWidgets('spent holds one frame and nothing ticks', (tester) async {
      await pumpBox(tester, phase: ChestPhase.spent);
      await tester.pumpAndSettle();

      expect(progress(tester), closeTo(392 / _frames, 1e-3));
    });
  });

  group('a still box', () {
    testWidgets('shows the first idle frame and does not tick', (tester) async {
      await pumpBox(tester, phase: ChestPhase.ready, still: true);
      await tester.pumpAndSettle();

      expect(progress(tester), 0);
    });

    testWidgets('a spent chest shows the spent frame', (tester) async {
      await pumpBox(tester, phase: ChestPhase.spent, still: true);
      await tester.pumpAndSettle();

      expect(progress(tester), closeTo(392 / _frames, 1e-3));
    });
  });

  group('reduced motion', () {
    testWidgets('every phase is one frame, and nothing ticks', (tester) async {
      const Map<ChestPhase, int> expected = <ChestPhase, int>{
        ChestPhase.ready: 0,
        ChestPhase.charging: 0,
        ChestPhase.opening: 270,
        ChestPhase.revealed: 270,
        ChestPhase.spent: 392,
      };
      for (final MapEntry<ChestPhase, int> e in expected.entries) {
        await pumpBox(tester, phase: e.key, reduceMotion: true);
        await tester.pumpAndSettle();
        expect(progress(tester), closeTo(e.value / _frames, 1e-3), reason: e.key.name);
      }
    });

    testWidgets('open fires neither callback: the page shows the prize at once', (tester) async {
      int calls = 0;
      await pumpBox(tester, phase: ChestPhase.ready, reduceMotion: true);
      await pumpBox(
        tester,
        phase: ChestPhase.opening,
        reduceMotion: true,
        onBurst: () => calls++,
        onOpened: () => calls++,
      );
      await tester.pump(const Duration(seconds: 3));

      expect(calls, 0);
    });
  });

  group('tint', () {
    List<ValueDelegate> delegates(WidgetTester tester) => lottie(tester).delegates!.values!;

    ValueDelegate? at(WidgetTester tester, List<String> keyPath) {
      for (final ValueDelegate d in delegates(tester)) {
        if (d.keyPath.join('/') == keyPath.join('/')) return d;
      }
      return null;
    }

    testWidgets('the glow is common green while the chest is closed', (tester) async {
      await pumpBox(tester, phase: ChestPhase.ready);

      expect(at(tester, chestGlowKeyPath)!.value, ChestTier.common.color);
    });

    testWidgets('the glow takes the tier colour once it is known', (tester) async {
      await pumpBox(tester, phase: ChestPhase.opening, glow: ChestTier.legendary.color);

      expect(at(tester, chestGlowKeyPath)!.value, ChestTier.legendary.color);
    });

    testWidgets('a vivid accent tints the three accent layers', (tester) async {
      const Color primary = Color(0xFFE91E63);
      await pumpBox(tester, phase: ChestPhase.ready);
      final ChestAccent accent = chestAccentOf(primary)!;

      expect(at(tester, chestAccentLightKeyPath)!.value, accent.light);
      expect(at(tester, chestAccentMidKeyPath)!.value, primary);
      expect(at(tester, chestAccentDarkKeyPath)!.value, accent.dark);
    });

    testWidgets('a grey accent leaves the accent layers purple', (tester) async {
      await pumpBox(tester, phase: ChestPhase.ready, primary: const Color(0xFFFFFFFF));

      expect(at(tester, chestAccentMidKeyPath), isNull);
      expect(at(tester, chestGlowKeyPath), isNotNull);
    });
  });
}
