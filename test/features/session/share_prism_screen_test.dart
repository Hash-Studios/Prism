import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/session/views/pages/share_prism_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> toasts = <String>[];
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    // No id: the page cannot create a link, which keeps the test off the network.
    app_state.prismUser = profileUser(id: '');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    SharePrismScreen.createLinkForTesting = null;
    AnalyticsRuntime.reset();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SharePrismScreen()));
    // Glint loops, so pump a bounded time instead of settling.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('says what both sides get and offers to share', (tester) async {
    await pumpPage(tester);

    expect(find.text('Invite friends'), findsOneWidget);
    expect(find.text('Give 100, get 100'), findsOneWidget);
    expect(find.text('Your friend gets 100 coins when they join. You get 100 too.'), findsOneWidget);
    expect(find.text('Share invite'), findsOneWidget);
  });

  testWidgets('without an account the link card says to sign in and sharing is blocked with a toast', (tester) async {
    await pumpPage(tester);

    expect(find.text('Sign in to get your invite link.'), findsOneWidget);
    expect(find.byTooltip('Copy link'), findsNothing);

    await tester.tap(find.text('Share invite'));
    await tester.pump();

    expect(toasts, contains('Sign in to get your invite link.'));
    expect(analytics.events.map((e) => e.eventName), contains('invite_share_tapped'));
    await tester.pump(const Duration(seconds: 2));
  });

  void signIn() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'uid1'
      ..loggedIn = true;
  }

  testWidgets('shows a loading state while the link is made, then offers Share invite', (tester) async {
    signIn();
    final link = Completer<String>();
    SharePrismScreen.createLinkForTesting = (_) => link.future;

    await pumpPage(tester);
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).loading, isTrue);

    link.complete('https://prismwalls.com/s/abc');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Share invite'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).loading, isFalse);
    expect(find.text('https://prismwalls.com/s/abc'), findsOneWidget);
    expect(find.byTooltip('Copy link'), findsOneWidget);
  });

  testWidgets('a failed link shows a retry, never a sign in message, and recovers', (tester) async {
    signIn();
    var calls = 0;
    SharePrismScreen.createLinkForTesting = (_) async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return 'https://prismwalls.com/s/abc';
    };

    await pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Could not create your invite link.'), findsOneWidget);
    expect(find.byTooltip('Try again'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
    expect(toasts.where((m) => m.contains('Sign in')), isEmpty);

    await tester.tap(find.byTooltip('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('https://prismwalls.com/s/abc'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('a signed out user is asked to sign in and no link is requested', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    var called = false;
    SharePrismScreen.createLinkForTesting = (_) async {
      called = true;
      return 'x';
    };

    await pumpPage(tester);
    await tester.tap(find.text('Share invite'));
    await tester.pump();

    expect(called, isFalse);
    expect(toasts, contains('Sign in to get your invite link.'));
    await tester.pump(const Duration(seconds: 2));
  });
}
