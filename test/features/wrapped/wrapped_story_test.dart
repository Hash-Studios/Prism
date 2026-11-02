import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/pages/wrapped_page.dart';
import 'package:Prism/features/wrapped/views/wrapped_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import 'wrapped_fixture.dart';

class _FakeShare {
  final List<WrappedCard> cards = <WrappedCard>[];
  final List<WrappedCopy> copies = <WrappedCopy>[];
  final List<String> ownerUserIds = <String>[];
  Object? error;

  Future<void> call(
    BuildContext context, {
    required WrappedCard card,
    required WrappedCopy copy,
    required Color accent,
    required String ownerUserId,
    Stream<String>? ownerChanges,
  }) async {
    cards.add(card);
    copies.add(copy);
    ownerUserIds.add(ownerUserId);
    final Object? failure = error;
    if (failure != null) throw failure;
  }
}

/// A home page with a button that pushes the story as a route, so a pop can be observed.
class _Home extends StatelessWidget {
  const _Home({required this.year, required this.share});

  final WrappedYear year;
  final _FakeShare share;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: WrappedStory(
                year: year,
                source: WrappedSourceValue.home,
                ownerUserId: 'test-user',
                share: share.call,
              ),
            ),
          ),
        ),
        child: const Text('Open story'),
      ),
    ),
  );
}

Future<void> _pumpStory(
  WidgetTester tester, {
  required _FakeShare share,
  bool reduceMotion = false,
  bool accessibleNavigation = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      // Above the Navigator, so the pushed story route inherits the flag.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: reduceMotion, accessibleNavigation: accessibleNavigation),
        child: child!,
      ),
      home: _Home(year: fixtureWrappedYear(), share: share),
    ),
  );
  await tester.tap(find.text('Open story'));
  // The pushed route needs a second frame before it builds.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tapRight(WidgetTester tester) async {
  final Size size = tester.getSize(find.byType(WrappedStory));
  await tester.tapAt(Offset(size.width * 0.8, size.height / 2));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tapLeft(WidgetTester tester) async {
  final Size size = tester.getSize(find.byType(WrappedStory));
  await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(AnalyticsRuntime.reset);

  testWidgets('starts on the intro and a right tap shows the saves card', (tester) async {
    await _pumpStory(tester, share: _FakeShare());

    expect(find.text('Prism Wrapped 2026'), findsOneWidget);
    expect(find.text('Your year in walls'), findsOneWidget);

    await _tapRight(tester);
    expect(find.text('You saved 12 walls in 2026.'), findsOneWidget);

    await _tapLeft(tester);
    expect(find.text('Your year in walls'), findsOneWidget);
  });

  testWidgets('skips the ai card and ends on the summary with a share button', (tester) async {
    await _pumpStory(tester, share: _FakeShare());

    for (int i = 0; i < 5; i++) {
      expect(find.text('Made with AI'), findsNothing);
      await _tapRight(tester);
    }

    expect(find.text('Your 2026 in Prism'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Made with AI'), findsNothing);
  });

  testWidgets('advances by itself after one card duration', (tester) async {
    await _pumpStory(tester, share: _FakeShare());

    await tester.pump(wrappedCardDuration + const Duration(milliseconds: 100));

    expect(find.text('You saved 12 walls in 2026.'), findsOneWidget);
  });

  testWidgets('holding pauses the story and releasing resumes it', (tester) async {
    await _pumpStory(tester, share: _FakeShare());

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(WrappedStory)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Your year in walls'), findsOneWidget);
    expect(find.text('You saved 12 walls in 2026.'), findsNothing);

    await gesture.up();
    // The ticker starts counting on the frame after release, so the first pump only starts the timer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 6100));
    expect(find.text('You saved 12 walls in 2026.'), findsOneWidget);
  });

  testWidgets('reduced motion never moves by itself and shows next and previous buttons', (tester) async {
    await _pumpStory(tester, share: _FakeShare(), reduceMotion: true);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Your year in walls'), findsOneWidget);
    expect(find.text('You saved 12 walls in 2026.'), findsNothing);

    await tester.tap(find.byTooltip('Next card'));
    await tester.pump();
    expect(find.text('You saved 12 walls in 2026.'), findsOneWidget);
  });

  testWidgets('screen-reader navigation disables story transitions', (tester) async {
    await _pumpStory(tester, share: _FakeShare(), accessibleNavigation: true);

    expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration, Duration.zero);
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration, Duration.zero);
  });

  testWidgets('swipe down closes the story and returns to the home page', (tester) async {
    await _pumpStory(tester, share: _FakeShare());

    await tester.drag(find.byType(WrappedStory), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.byType(WrappedStory), findsNothing);
    expect(find.text('Open story'), findsOneWidget);
  });

  testWidgets('exposes the card position and copy to screen readers', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpStory(tester, share: _FakeShare());

    expect(find.bySemanticsLabel(RegExp(r'^Card 1 of 6\. Prism Wrapped 2026')), findsOneWidget);

    await _tapRight(tester);
    expect(find.bySemanticsLabel(RegExp(r'Card 2 of 6.*You saved 12 walls in 2026\.')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('share button sends the current card and its copy', (tester) async {
    final _FakeShare share = _FakeShare();
    await _pumpStory(tester, share: share);

    await _tapRight(tester);
    await tester.tap(find.byTooltip('Share this card'));
    await tester.pump();

    expect(share.cards, hasLength(1));
    expect(share.cards.single.kind, WrappedCardKind.saves);
    expect(share.copies.single.body, 'You saved 12 walls in 2026.');
    expect(share.ownerUserIds, <String>['test-user']);
  });

  testWidgets('a failed share shows the story controls again', (tester) async {
    final _FakeShare share = _FakeShare()..error = StateError('share failed');
    await _pumpStory(tester, share: share);

    final List<Object> errors = <Object>[];
    await runZonedGuarded(() async {
      await tester.tap(find.byTooltip('Share this card'));
      await tester.pump();
    }, (error, _) => errors.add(error));
    await tester.pump(const Duration(seconds: 1));
    expect(errors.single, isStateError);

    final AnimatedOpacity chrome = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byTooltip('Share this card'), matching: find.byType(AnimatedOpacity)).first,
    );
    expect(chrome.opacity, 1);
  });

  testWidgets('tracks open, one view per card and a single finish', (tester) async {
    await _pumpStory(tester, share: _FakeShare());

    for (int i = 0; i < 5; i++) {
      await _tapRight(tester);
    }

    final List<String> names = analytics.events.map((AnalyticsEvent e) => e.eventName).toList();
    expect(names.where((String n) => n == 'wrapped_opened'), hasLength(1));
    expect(names.where((String n) => n == 'wrapped_card_viewed'), hasLength(6));
    expect(names.where((String n) => n == 'wrapped_finished'), hasLength(1));
  });
}
