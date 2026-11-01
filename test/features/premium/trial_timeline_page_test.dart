import 'dart:async';

import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:Prism/features/premium/views/pages/trial_timeline_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

TrialOffer _offer(int days) => TrialOffer(
  package: const Package(
    r'$rc_annual',
    PackageType.annual,
    StoreProduct('prism_pro_yearly', '', '', 1499, '₹1,499.00', 'INR'),
    PresentedOfferingContext('main', null, null),
  ),
  days: days,
);

TrialTimelinePage _page({
  int days = 7,
  Future<bool> Function({required bool remind})? onStartTrial,
  ValueChanged<bool>? onReminderToggled,
}) => TrialTimelinePage(
  offer: _offer(days),
  now: DateTime(2026, 11, 1, 12),
  storeName: 'App Store',
  onStartTrial: onStartTrial ?? ({required bool remind}) async => false,
  onReminderToggled: onReminderToggled ?? (_) {},
);

Widget _app(Widget home, {Locale? locale}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

late Future<TrialTimelineChoice?> _pushed;

Future<void> _reveal(WidgetTester tester, String text) => tester.scrollUntilVisible(
  find.text(text),
  200,
  scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
);

Future<void> _pumpPushed(WidgetTester tester, TrialTimelinePage page) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () {
                _pushed = Navigator.of(
                  context,
                ).push<TrialTimelineChoice>(MaterialPageRoute<TrialTimelineChoice>(builder: (_) => page));
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  testWidgets('English timeline shows dates, price, renewal terms and actions', (tester) async {
    await tester.pumpWidget(_app(_page()));
    await tester.pump();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Nov 1'), findsOneWidget);
    expect(find.text('Day 5'), findsOneWidget);
    expect(find.text('Nov 6'), findsOneWidget);
    expect(find.text('Day 7'), findsOneWidget);
    expect(find.text('Nov 8'), findsOneWidget);
    expect(find.text('You pay ₹1,499.00, unless you cancel at least 24 hours before.'), findsOneWidget);
    expect(find.text('Prism Pro yearly. 7 days free, then ₹1,499.00 a year.'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    await _reveal(tester, 'Cancel any time in App Store settings');
    expect(find.text('Cancel any time in App Store settings'), findsOneWidget);
    await _reveal(tester, 'Remind me 2 days before the trial ends');
    expect(find.text('Remind me 2 days before the trial ends'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('German locale formats the timeline date in German', (tester) async {
    final String germanDate = DateFormat.MMMd('de').format(DateTime(2026, 11, 6));
    expect(germanDate, '6. Nov.');

    await tester.pumpWidget(_app(_page(), locale: const Locale('de')));
    await tester.pump();

    expect(find.text(germanDate), findsOneWidget);
    expect(find.textContaining('₹1,499.00'), findsWidgets);
  });

  testWidgets('timeline dates advance by calendar day across the spring DST change', (tester) async {
    await tester.pumpWidget(
      _app(
        TrialTimelinePage(
          offer: _offer(3),
          now: DateTime(2026, 3, 7, 23, 30),
          storeName: 'App Store',
          onStartTrial: ({required bool remind}) async => false,
          onReminderToggled: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mar 7'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Mar 8'), findsOneWidget);
    expect(find.text('Day 3'), findsOneWidget);
    expect(find.text('Mar 10'), findsOneWidget);
  });

  testWidgets('turning the reminder off passes false and shows the no-reminder copy', (tester) async {
    final List<bool> toggled = <bool>[];
    final List<bool> started = <bool>[];
    await tester.pumpWidget(
      _app(
        _page(
          onReminderToggled: toggled.add,
          onStartTrial: ({required bool remind}) async {
            started.add(remind);
            return false;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(toggled, <bool>[false]);
    expect(find.text('No reminder. You turned it off below.'), findsOneWidget);

    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();

    expect(started, <bool>[false]);
  });

  testWidgets('a start that the store confirms pops with started', (tester) async {
    await _pumpPushed(tester, _page(onStartTrial: ({required bool remind}) async => true));

    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();

    expect(await _pushed, TrialTimelineChoice.started);
    expect(find.text('Start 7-day free trial'), findsNothing);
  });

  testWidgets('a cancelled store purchase keeps the page open and can be retried', (tester) async {
    int attempts = 0;
    await _pumpPushed(tester, _page(onStartTrial: ({required bool remind}) async => ++attempts > 1));

    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.text('Start 7-day free trial'), findsOneWidget);

    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(await _pushed, TrialTimelineChoice.started);
  });

  testWidgets('Close pops with closed', (tester) async {
    await _pumpPushed(tester, _page());

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(await _pushed, TrialTimelineChoice.closed);
  });

  testWidgets('closing while purchase is pending does not pop the underlying route on late success', (tester) async {
    final Completer<bool> purchase = Completer<bool>();
    await _pumpPushed(tester, _page(onStartTrial: ({required bool remind}) => purchase.future));

    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 50));

    purchase.complete(true);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(await _pushed, TrialTimelineChoice.closed);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('system back while purchase is pending does not pop the underlying route on late success', (
    tester,
  ) async {
    final Completer<bool> purchase = Completer<bool>();
    await _pumpPushed(tester, _page(onStartTrial: ({required bool remind}) => purchase.future));

    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 50));

    purchase.complete(true);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(await _pushed, isNull);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('See all plans pops with seeAllPlans', (tester) async {
    await _pumpPushed(tester, _page());

    await _reveal(tester, 'See all plans');
    await tester.tap(find.text('See all plans'));
    await tester.pumpAndSettle();

    expect(await _pushed, TrialTimelineChoice.seeAllPlans);
  });

  testWidgets('large text keeps the close button on screen without errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: _page(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Close'), findsOneWidget);
    final double closeTop = tester.getRect(find.byTooltip('Close')).top;
    expect(closeTop, greaterThanOrEqualTo(0));
    expect(closeTop, lessThan(200));
    final Text title = tester.widget<Text>(find.text('How your free trial works'));
    expect(title.maxLines, isNull, reason: 'the title wraps and never loses words at large text');
  });

  testWidgets('a two-day trial has no reminder step or switch', (tester) async {
    await tester.pumpWidget(_app(_page(days: 2)));
    await tester.pump();

    expect(find.text('Day 0'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Day 2'), findsOneWidget);
  });
}
