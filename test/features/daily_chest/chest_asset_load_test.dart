import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:Prism/features/daily_chest/views/pages/daily_chest_page.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_box.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_reveal_card.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_span.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import '../../qa_render/qa_harness.dart' show loadFonts;
import '../quests/fake_quests_repository.dart';

const double _frames = 393;

/// Serves the chest file once the test lets it, so a test can choose the frame at which the file lands. Every other
/// asset comes from the real bundle.
class _ChestFileBundle extends AssetBundle {
  _ChestFileBundle(String json) : _bytes = Uint8List.fromList(utf8.encode(json));

  final Uint8List _bytes;
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<ByteData> load(String key) async {
    if (key != chestAsset) return rootBundle.load(key);
    await _gate.future;
    return ByteData.sublistView(_bytes);
  }
}

String _chestFile() => File(chestAsset).readAsStringSync();

/// Waits for the load of the file, outside fake time too, and lets the widget take the result.
Future<void> _waitForFile(WidgetTester tester) async {
  bool landed() => tester.widget<Lottie>(find.byType(Lottie)).composition != null;
  for (int i = 0; i < 100 && !landed(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(landed(), isTrue, reason: 'the file loaded');
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (Duration t = Duration.zero; t < total; t += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadFonts);

  // Lottie keeps a loaded file by asset name, whatever bundle served it.
  setUp(() => Lottie.cache.clear());
  tearDown(() => Lottie.cache.clear());

  group('ChestBox with the file', () {
    late int bursts;
    late int opened;

    setUp(() {
      bursts = 0;
      opened = 0;
    });

    Future<void> pumpBox(WidgetTester tester, ChestPhase phase, {AssetBundle? bundle}) {
      final Widget box = ChestBox(phase: phase, size: 200, onBurst: () => bursts++, onOpened: () => opened++);
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Center(
            child: bundle == null ? box : DefaultAssetBundle(bundle: bundle, child: box),
          ),
        ),
      );
    }

    double progress(WidgetTester tester) => tester.widget<LottieBuilder>(find.byType(LottieBuilder)).controller!.value;

    testWidgets('the file in the app has the spans the box plays before it has loaded', (tester) async {
      await pumpBox(tester, ChestPhase.ready);
      await _waitForFile(tester);
      final LottieComposition file = tester.widget<Lottie>(find.byType(Lottie)).composition!;

      for (final ChestMarker marker in chestMarkers.values) {
        final ChestSpan fromFile = ChestSpan.of(marker, file);
        final ChestSpan fallback = ChestSpan.of(marker, null);
        expect(fromFile.from, closeTo(fallback.from, 1e-4), reason: marker.name);
        expect(fromFile.to, closeTo(fallback.to, 1e-4), reason: marker.name);
        expect(fromFile.duration.inMicroseconds, closeTo(fallback.duration.inMicroseconds, 1000), reason: marker.name);
      }
    });

    testWidgets('the open span is the one the file marks: a longer open takes longer to end', (tester) async {
      final Map<String, Object?> json = jsonDecode(_chestFile()) as Map<String, Object?>;
      for (final Map<String, Object?> marker in (json['markers']! as List<Object?>).cast<Map<String, Object?>>()) {
        if (marker['cm'] == 'open') marker['dr'] = 120;
      }
      final _ChestFileBundle bundle = _ChestFileBundle(jsonEncode(json))..release();
      await pumpBox(tester, ChestPhase.opening, bundle: bundle);
      await _waitForFile(tester);

      expect(progress(tester), closeTo(180 / _frames, 1e-3));
      await tester.pump(const Duration(milliseconds: 1700));
      expect(opened, 0, reason: 'the built in span would be over after 1.5 s, this file asks for 2 s');
      await tester.pump(const Duration(milliseconds: 400));
      expect(opened, 1);
      expect(progress(tester), closeTo(300 / _frames, 1e-3));
    });

    testWidgets('a load that lands while the box opens plays the open span again and ends it once', (tester) async {
      final _ChestFileBundle bundle = _ChestFileBundle(_chestFile());
      addTearDown(bundle.release);
      await pumpBox(tester, ChestPhase.opening, bundle: bundle);
      await _pumpFor(tester, const Duration(milliseconds: 400));
      expect((bursts, opened), (1, 0), reason: 'the built in timeline bursts at frame 196');
      expect(progress(tester), greaterThan(190 / _frames));

      bundle.release();
      await _waitForFile(tester);

      expect(progress(tester), closeTo(180 / _frames, 1e-3), reason: 'it starts the span again');
      await _pumpFor(tester, const Duration(milliseconds: 2000));
      expect(opened, 1);
      expect(bursts, inInclusiveRange(1, 2), reason: 'the restart may burst again, the page keeps one card');
      expect(progress(tester), closeTo(270 / _frames, 1e-3));
    });
  });

  group('the page with a late file', () {
    final List<String> haptics = <String>[];
    const MethodChannel hapticChannel = MethodChannel('prism/haptics');

    setUp(() {
      haptics.clear();
      PrismHaptics.enabled = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, (
        MethodCall call,
      ) async {
        if (call.method == 'play') haptics.add(call.arguments as String);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, null);
      app_state.prismUser = app_constants.createGuestPrismUser();
    });

    testWidgets('a load that lands after the burst does not raise a second card or a second success', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final ValueNotifier<QuestState?> quests = ValueNotifier<QuestState?>(
        questState(
          dayKey: '2026-10-18',
          items: <QuestItem>[
            questItem('set_wall', QuestEvent.setWallpaper),
            questItem('fav_3', QuestEvent.favourite, target: 3),
            questItem('wotd_view', QuestEvent.viewWotd),
          ],
        ),
      );
      final ValueNotifier<int> balance = ValueNotifier<int>(340);
      addTearDown(quests.dispose);
      addTearDown(balance.dispose);
      final _ChestFileBundle bundle = _ChestFileBundle(_chestFile());
      addTearDown(bundle.release);
      final Completer<DailyChestResult> reply = Completer<DailyChestResult>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: kLightTheme,
          builder: (BuildContext context, Widget? child) => DefaultAssetBundle(bundle: bundle, child: child!),
          home: DailyChestPage(
            open: ({required int maxCost}) => reply.future.then((DailyChestResult result) {
              if (result is ChestWon) balance.value += result.win.coins - result.cost;
              return result;
            }),
            quests: quests,
            balance: balance,
            now: () => DateTime.utc(2026, 10, 18, 18, 48),
            refresh: () async {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Open'));
      await tester.pump();
      reply.complete(const ChestWon(win: ChestWin(slot: 3, coins: 20), cost: 8, doubled: false, slots: defaultChest));
      await _pumpFor(tester, const Duration(milliseconds: 1100));
      expect(find.byType(ChestRevealCard), findsOneWidget, reason: 'the first burst raised the card');
      expect(tester.widget<ChestBox>(find.byType(ChestBox)).phase, ChestPhase.opening);
      expect(haptics, <String>['tap', 'success']);
      expect(find.text('352'), findsOneWidget);

      bundle.release();
      await _waitForFile(tester);
      await _pumpFor(tester, const Duration(milliseconds: 3000));

      expect(tester.widget<ChestBox>(find.byType(ChestBox)).phase, ChestPhase.revealed);
      expect(find.byType(ChestRevealCard), findsOneWidget);
      expect(haptics, <String>['tap', 'success']);
    });
  });
}
