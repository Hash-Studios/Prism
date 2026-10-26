// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import '../support/fake_app_analytics.dart';

class _FailingGooglePlatform extends GoogleSignInPlatform {
  final Completer<AuthenticationResults> result = Completer<AuthenticationResults>();

  @override
  Future<void> init(InitParameters params) async {}

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) => result.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  for (final entry in <GoogleSignInExceptionCode, String>{
    GoogleSignInExceptionCode.providerConfigurationError: 'Google Play services on this device cannot sign in.',
    GoogleSignInExceptionCode.unknownError: 'Google sign-in failed. Check your connection and try again.',
  }.entries) {
    testWidgets('popup maps ${entry.key.name} and dismisses the loading sheet', (tester) async {
      final previousPlatform = GoogleSignInPlatform.instance;
      final platform = _FailingGooglePlatform();
      GoogleSignInPlatform.instance = platform;
      AnalyticsRuntime.instance = FakeAppAnalytics();
      final List<String> messages = <String>[];
      const channel = MethodChannel('PonnamKarthik/fluttertoast');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'showToast') messages.add((call.arguments as Map)['msg'] as String);
        return true;
      });
      addTearDown(() {
        GoogleSignInPlatform.instance = previousPlatform;
        AnalyticsRuntime.reset();
        messenger.setMockMethodCallHandler(channel, null);
      });
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int successes = 0;
      Future<bool>? signedIn;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => signedIn = googleSignInPopUp(context, () => successes++),
                child: const Text('Open sign-in'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sign-in'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Signing in'), findsOneWidget);

      platform.result.completeError(GoogleSignInException(code: entry.key));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Signing in'), findsNothing);
      expect(successes, 0);
      expect(await signedIn, isFalse);
      expect(messages, <String>[entry.value]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
