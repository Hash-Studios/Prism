import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/navigation/views/widgets/nav_glass.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

Widget _host({bool reduceMotion = false, bool tickerEnabled = true}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: app!,
  ),
  home: Scaffold(
    body: Center(
      child: TickerMode(enabled: tickerEnabled, child: const PrismFab()),
    ),
  ),
);

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = app_constants.createGuestPrismUser();
  });
  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  group('tap', () {
    testWidgets('a signed in user gets the create sheet and one upload analytics event', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = true;
      await tester.pumpWidget(_host(reduceMotion: true));

      await tester.tap(find.bySemanticsLabel('Upload'));
      await tester.pumpAndSettle();

      expect(find.byType(UploadBottomPanel), findsOneWidget);
      expect(analytics.events.where((e) => e.eventName == 'upload_action_selected'), hasLength(1));
    });

    testWidgets('a guest gets the sign in sheet and not the create sheet', (tester) async {
      await tester.pumpWidget(_host(reduceMotion: true));

      await tester.tap(find.bySemanticsLabel('Upload'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Prism'), findsOneWidget);
      expect(find.byType(UploadBottomPanel), findsNothing);
      expect(analytics.events.where((e) => e.eventName == 'upload_action_selected'), hasLength(1));
    });
  });

  testWidgets('the create button is a glass disc with an ink plus inside the brand ring', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));

    final Finder glass = find.descendant(of: find.byType(PrismFab), matching: find.byType(NavGlass));
    expect(glass, findsOneWidget);
    expect(tester.widget<NavGlass>(glass).circle, isTrue);
    expect(tester.getSize(glass), const Size(56, 56));
    final Icon plus = tester.widget<Icon>(find.descendant(of: glass, matching: find.byIcon(Icons.add_rounded)));
    expect(plus.color, Theme.of(tester.element(glass)).colorScheme.secondary);

    final ClipPath ring = tester.widget<ClipPath>(
      find.ancestor(of: find.byType(RotationTransition), matching: find.byType(ClipPath)).first,
    );
    final Path clip = ring.clipper!.getClip(const Size(56, 56));
    expect(clip.contains(const Offset(28, 28)), isFalse, reason: 'the centre is glass, not rainbow art');
    expect(clip.contains(const Offset(28 + 23, 28)), isTrue, reason: 'the ring band shows the rainbow art');
  });

  group('rings', () {
    List<double> ringTurns(WidgetTester tester) => tester
        .widgetList<RotationTransition>(
          find.descendant(of: find.byType(PrismFab), matching: find.byType(RotationTransition)),
        )
        .map((ring) => ring.turns.value)
        .toList();

    double turns(WidgetTester tester) => ringTurns(tester).first;

    testWidgets('turn once over five seconds while motion is allowed', (tester) async {
      await tester.pumpWidget(_host());
      expect(turns(tester), 0);

      await tester.pump(const Duration(seconds: 1));

      expect(turns(tester), closeTo(0.2, 0.01));
    });

    testWidgets('rest after one turn, so the screen stops drawing frames', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));

      expect(ringTurns(tester), <double>[1]);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_host(reduceMotion: true));
      await tester.pump(const Duration(seconds: 1));
      expect(ringTurns(tester), <double>[1]);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_host());
      await tester.pump(const Duration(seconds: 1));
      expect(ringTurns(tester), <double>[1]);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_host(tickerEnabled: false));
      await tester.pump(const Duration(seconds: 1));
      expect(ringTurns(tester), <double>[1]);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_host());
      await tester.pump(const Duration(seconds: 1));
      expect(ringTurns(tester), <double>[1]);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('stay still when the system asks for less motion', (tester) async {
      await tester.pumpWidget(_host(reduceMotion: true));

      await tester.pump(const Duration(seconds: 1));

      expect(turns(tester), 0);
    });

    testWidgets('pause the turn when reduced motion is enabled, then resume from the same pose', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(seconds: 1));
      final double beforeReduceMotion = turns(tester);
      expect(beforeReduceMotion, closeTo(0.2, 0.01));

      await tester.pumpWidget(_host(reduceMotion: true));
      await tester.pump(const Duration(seconds: 8));
      expect(turns(tester), beforeReduceMotion);

      await tester.pumpWidget(_host());
      await tester.pump(const Duration(seconds: 1));
      expect(turns(tester), greaterThan(beforeReduceMotion));
      expect(turns(tester), closeTo(0.4, 0.01));
    });

    testWidgets('stop while their tab is hidden and go on when it comes back', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(seconds: 1));
      final double beforeHide = turns(tester);

      await tester.pumpWidget(_host(tickerEnabled: false));
      await tester.pump(const Duration(seconds: 8));
      expect(turns(tester), beforeHide);

      await tester.pumpWidget(_host());
      await tester.pump(const Duration(seconds: 1));
      expect(turns(tester), closeTo(0.4, 0.01));
    });
  });
}
