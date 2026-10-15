import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/rating/rate_prompt_sheet.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

class _Harness {
  _Harness({
    this.choice = RatePromptChoice.yes,
    this.platform = TargetPlatform.android,
    this.slotFree = true,
    this.androidStoreOpens = true,
  }) {
    service = RatePromptService(
      read: <T>(String key, T defaultValue) => (store[key] as T?) ?? defaultValue,
      write: (String key, Object? value) async => store[key] = value,
      clock: () => now,
      firstLaunchAt: () => firstLaunch,
      appVersion: () => version,
      platform: () => platform,
      claimStartupSlot: () {
        claims += 1;
        return slotFree;
      },
      showQuestion: (BuildContext context) async {
        questions += 1;
        return choice;
      },
      launch: (Uri uri) async {
        launched.add(uri.toString());
        return uri.scheme != 'market' || androidStoreOpens;
      },
      openReportProblem: (BuildContext context) async => reportOpened += 1,
      track: (AnalyticsEvent event) async => events.add(event),
    );
  }

  final RatePromptChoice choice;
  final TargetPlatform platform;
  final bool slotFree;
  final bool androidStoreOpens;
  final Map<String, Object?> store = <String, Object?>{};
  final List<String> launched = <String>[];
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  DateTime now = DateTime.utc(2026, 3, 20);
  DateTime firstLaunch = DateTime.utc(2026, 3);
  String version = '3.4.0';
  int claims = 0;
  int questions = 0;
  int reportOpened = 0;
  late final RatePromptService service;

  Future<void> actions(BuildContext context, int count) async {
    for (var i = 0; i < count; i++) {
      await service.maybePrompt(context, RatePromptTrigger.wallpaperSet);
    }
  }
}

void main() {
  testWidgets('asks on the third set or download, not before', (tester) async {
    final h = _Harness();
    final context = await _pumpContext(tester);

    await h.actions(context, 2);
    expect(h.questions, 0);
    expect(h.claims, 0);

    await h.service.maybePrompt(context, RatePromptTrigger.download);
    expect(h.questions, 1);
    final shown = h.events.whereType<RatePromptShownEvent>().single;
    expect(shown.trigger, 'download');
  });

  testWidgets('waits five days after the first launch', (tester) async {
    final h = _Harness()..firstLaunch = DateTime.utc(2026, 3, 17);
    final context = await _pumpContext(tester);

    await h.actions(context, 3);
    expect(h.questions, 0);

    h.now = DateTime.utc(2026, 3, 22);
    await h.service.maybePrompt(context, RatePromptTrigger.wallpaperSet);
    expect(h.questions, 1);
  });

  testWidgets('leaves 14 days between asks', (tester) async {
    final h = _Harness(choice: RatePromptChoice.dismissed);
    final context = await _pumpContext(tester);
    await h.actions(context, 3);
    expect(h.questions, 1);

    h.now = h.now.add(const Duration(days: 13));
    await h.service.maybePrompt(context, RatePromptTrigger.wallpaperSet);
    expect(h.questions, 1);

    h.now = h.now.add(const Duration(days: 1));
    await h.service.maybePrompt(context, RatePromptTrigger.wallpaperSet);
    expect(h.questions, 2);
  });

  testWidgets('asks at most three times per app version, and again after an update', (tester) async {
    final h = _Harness(choice: RatePromptChoice.dismissed);
    final context = await _pumpContext(tester);
    await h.actions(context, 3);

    for (var i = 0; i < 4; i++) {
      h.now = h.now.add(const Duration(days: 15));
      await h.service.maybePrompt(context, RatePromptTrigger.wallpaperSet);
    }
    expect(h.questions, 3);

    h.version = '3.5.0';
    h.now = h.now.add(const Duration(days: 15));
    await h.service.maybePrompt(context, RatePromptTrigger.wallpaperSet);
    expect(h.questions, 4);
  });

  testWidgets('does not ask in a session that already showed a startup sheet', (tester) async {
    final h = _Harness(slotFree: false);
    final context = await _pumpContext(tester);

    await h.actions(context, 3);

    expect(h.claims, 1);
    expect(h.questions, 0);
    expect(h.store.containsKey(RatePromptService.lastAskAtKey), isFalse);
  });

  testWidgets('Yes opens the Play Store and never asks again', (tester) async {
    final h = _Harness();
    final context = await _pumpContext(tester);
    await h.actions(context, 3);

    expect(h.launched, <String>['market://details?id=com.hash.prism']);
    expect(h.events.whereType<RatePromptResultEvent>().single.result, 'yes');

    h.now = h.now.add(const Duration(days: 60));
    await h.service.maybePrompt(context, RatePromptTrigger.wallpaperSet);
    expect(h.questions, 1);
  });

  testWidgets('Yes falls back to the Play Store web page when no store app opens', (tester) async {
    final h = _Harness(androidStoreOpens: false);
    final context = await _pumpContext(tester);

    await h.actions(context, 3);

    expect(h.launched, <String>[
      'market://details?id=com.hash.prism',
      'https://play.google.com/store/apps/details?id=com.hash.prism',
    ]);
  });

  testWidgets('Yes on iOS opens the App Store review page', (tester) async {
    final h = _Harness(platform: TargetPlatform.iOS);
    final context = await _pumpContext(tester);

    await h.actions(context, 3);

    expect(h.launched, <String>['https://apps.apple.com/app/id1405860595?action=write-review']);
  });

  testWidgets('Not really opens Report a problem and still counts as an ask', (tester) async {
    final h = _Harness(choice: RatePromptChoice.notReally);
    final context = await _pumpContext(tester);

    await h.actions(context, 3);

    expect(h.reportOpened, 1);
    expect(h.launched, isEmpty);
    expect(h.events.whereType<RatePromptResultEvent>().single.result, 'not_really');
    expect(h.store[RatePromptService.asksInVersionKey], 1);
  });

  testWidgets('the sheet asks "Enjoying Prism?" and answers with the tapped button', (tester) async {
    StartupModalSlot.reset();
    final context = await _pumpContext(tester);
    final result = showRatePromptSheet(context);
    await tester.pumpAndSettle();

    expect(find.text('Enjoying Prism?'), findsOneWidget);
    await tester.tap(find.text('Not really'));
    await tester.pumpAndSettle();
    expect(await result, RatePromptChoice.notReally);

    final second = showRatePromptSheet(context);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(await second, RatePromptChoice.dismissed);
  });
}
