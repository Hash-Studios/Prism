import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_events.dart';
import 'package:Prism/features/rewards/views/widgets/coin_event_banner.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, dynamic> _weekly = <String, dynamic>{
  'id': 'weekend',
  'startDay': 6,
  'startMinute': 0,
  'durationMinutes': 2880,
  'multiplier': 2,
  'actions': <String>['rewardedAd'],
  'label': 'weekend',
};

CoinEventSchedule _weeklySchedule() => CoinEventSchedule.fromConfig(<String, dynamic>{'weeklyEvent': _weekly});

Widget _host(Widget child, {TextScaler? scaler, TextDirection? direction}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Directionality(
        textDirection: direction ?? TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(textScaler: scaler ?? TextScaler.noScaling),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('logs coin_event_seen once per event and phase', (tester) async {
    CoinEventBanner.resetSeenForTest();
    final List<AnalyticsEvent> tracked = <AnalyticsEvent>[];
    void listener(AnalyticsEvent event) => tracked.add(event);
    AnalyticsRuntime.trackListeners.add(listener);
    addTearDown(() => AnalyticsRuntime.trackListeners.remove(listener));

    await tester.pumpWidget(_host(CoinEventBanner(schedule: _weeklySchedule(), now: DateTime.utc(2026, 11, 14, 20))));
    await tester.pumpWidget(_host(CoinEventBanner(schedule: _weeklySchedule(), now: DateTime.utc(2026, 11, 14, 21))));
    await tester.pumpWidget(_host(CoinEventBanner(schedule: _weeklySchedule(), now: DateTime.utc(2026, 11, 12, 12))));

    final List<CoinEventSeenEvent> seen = tracked.whereType<CoinEventSeenEvent>().toList();
    expect(seen.map((e) => '${e.eventId}/${e.multiplier}/${e.phase}'), <String>[
      'weekend-2026-11-14/2/live',
      'weekend-2026-11-14/2/next',
    ]);
  });

  testWidgets('shows the live weekend event with its end and countdown', (tester) async {
    await tester.pumpWidget(_host(CoinEventBanner(schedule: _weeklySchedule(), now: DateTime.utc(2026, 11, 14, 20))));

    expect(find.text('Weekend 2x'), findsOneWidget);
    expect(find.textContaining('Ads pay 2x coins until'), findsOneWidget);
    expect(find.text('Ends in 1d 4h'), findsOneWidget);
  });

  testWidgets('shows the next weekend event with its start and countdown', (tester) async {
    await tester.pumpWidget(_host(CoinEventBanner(schedule: _weeklySchedule(), now: DateTime.utc(2026, 11, 12, 12))));

    expect(find.text('Weekend 2x'), findsOneWidget);
    expect(find.text('Starts in 1d 12h'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Text && (w.data ?? '').startsWith('Starts ') && !(w.data ?? '').startsWith('Starts in '),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows nothing when no event is scheduled', (tester) async {
    await tester.pumpWidget(
      _host(CoinEventBanner(schedule: CoinEventSchedule.none, now: DateTime.utc(2026, 11, 14, 20))),
    );

    expect(find.byKey(const ValueKey<String>('coin-event-banner')), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('countdown moves when the clock moves', (tester) async {
    final CoinEventSchedule schedule = _weeklySchedule();
    final DateTime now = DateTime.utc(2026, 11, 14, 20);
    await tester.pumpWidget(_host(CoinEventBanner(schedule: schedule, now: now)));
    expect(find.text('Ends in 1d 4h'), findsOneWidget);

    await tester.pumpWidget(_host(CoinEventBanner(schedule: schedule, now: now.add(const Duration(hours: 1)))));
    expect(find.text('Ends in 1d 3h'), findsOneWidget);
  });

  testWidgets('one-off event shows the multiplier title', (tester) async {
    final CoinEventSchedule schedule = CoinEventSchedule.fromConfig(<String, dynamic>{
      'events': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'launch',
          'startsAtMs': DateTime.utc(2026, 11, 14, 18).millisecondsSinceEpoch,
          'endsAtMs': DateTime.utc(2026, 11, 15, 18).millisecondsSinceEpoch,
          'multiplier': 2,
          'actions': <String>['rewardedAd'],
          'label': 'event',
        },
      ],
    });
    await tester.pumpWidget(_host(CoinEventBanner(schedule: schedule, now: DateTime.utc(2026, 11, 14, 20))));

    expect(find.text('2x coins'), findsOneWidget);
  });

  testWidgets('does not overflow at large text in a narrow box', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 320,
          child: CoinEventBanner(schedule: _weeklySchedule(), now: DateTime.utc(2026, 11, 14, 20)),
        ),
        scaler: const TextScaler.linear(2.0),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out in RTL with the same semantics label', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        CoinEventBanner(schedule: _weeklySchedule(), now: DateTime.utc(2026, 11, 14, 20)),
        direction: TextDirection.rtl,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('Weekend 2x')), findsOneWidget);
    handle.dispose();
  });

  group('formatCoinEventTime', () {
    test('uses weekday and 24 hour time within six days', () {
      expect(
        formatCoinEventTime(DateTime(2026, 11, 15, 23, 59), DateTime(2026, 11, 14, 20), 'en', use24h: true),
        'Sun 23:59',
      );
    });

    test('uses 12 hour time when 24 hour time is off', () {
      expect(
        formatCoinEventTime(DateTime(2026, 11, 15, 23, 59), DateTime(2026, 11, 14, 20), 'en', use24h: false),
        contains('PM'),
      );
    });

    test('uses month and day beyond six days', () {
      expect(
        formatCoinEventTime(DateTime(2026, 11, 24, 10), DateTime(2026, 11, 14, 20), 'en', use24h: true),
        contains('Nov'),
      );
    });
  });
}
