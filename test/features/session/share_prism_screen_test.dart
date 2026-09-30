import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
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
      toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    // No id: the page cannot create a link, which keeps the test off the network.
    app_state.prismUser = profileUser(id: '');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
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
  });
}
