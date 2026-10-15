import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/views/pages/share_prism_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PrismUsersV2 originalUser;
  late List<String> toastMessages;

  setUp(() {
    originalUser = app_state.prismUser;
    toastMessages = <String>[];
    AnalyticsRuntime.instance = FakeAppAnalytics();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        if (call.method == 'showToast') {
          toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
        }
        return true;
      },
    );
  });

  tearDown(() {
    app_state.prismUser = originalUser;
    SharePrismScreen.createLinkForTesting = null;
    AnalyticsRuntime.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
  });

  void signIn() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'uid1'
      ..loggedIn = true;
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SharePrismScreen()));
    await tester.pump();
  }

  testWidgets('shows a loading state while the link is made, then offers Share invite', (tester) async {
    signIn();
    final link = Completer<String>();
    SharePrismScreen.createLinkForTesting = (_) => link.future;

    await pumpScreen(tester);
    expect(find.text('Creating link…'), findsOneWidget);
    expect(tester.widget<MaterialButton>(find.byType(MaterialButton)).onPressed, isNull);

    link.complete('https://prismwalls.com/s/abc');
    await tester.pump();
    await tester.pump();
    expect(find.text('Share invite'), findsOneWidget);
    expect(tester.widget<MaterialButton>(find.byType(MaterialButton)).onPressed, isNotNull);
  });

  testWidgets('a failed link shows a retry, never a sign in message, and recovers', (tester) async {
    signIn();
    var calls = 0;
    SharePrismScreen.createLinkForTesting = (_) async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return 'https://prismwalls.com/s/abc';
    };

    await pumpScreen(tester);
    await tester.pump();
    expect(find.text("Couldn't create the link."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
    expect(toastMessages.where((m) => m.contains('Sign in')), isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Share invite'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('a signed out user is asked to sign in', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    var called = false;
    SharePrismScreen.createLinkForTesting = (_) async {
      called = true;
      return 'x';
    };

    await pumpScreen(tester);
    await tester.tap(find.byType(MaterialButton));
    await tester.pump();

    expect(called, isFalse);
    expect(toastMessages, contains('Sign in to generate unique referral link!'));
    await tester.pump(const Duration(seconds: 2));
  });
}
