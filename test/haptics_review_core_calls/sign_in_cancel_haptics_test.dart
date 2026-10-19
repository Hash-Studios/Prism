import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class _CancelledGoogleSignInPlatform extends GoogleSignInPlatform {
  @override
  Future<void> init(InitParameters params) async {}

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async =>
      throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('cancelling sign-in is silent: no toast and no success haptic', (tester) async {
    final GoogleSignInPlatform previousPlatform = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = _CancelledGoogleSignInPlatform();
    addTearDown(() => GoogleSignInPlatform.instance = previousPlatform);
    final List<Object?> hapticTypes = <Object?>[];
    final List<MethodCall> toastCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toastCalls.add(call);
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(toastChannel, null);
    });

    // The redesigned sign-in sheet is taller than the default 800x600 test surface.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => googleSignInPopUp(context, () {}), child: const Text('Open sign-in')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sign-in'));
    // The sign-in sheet mascot loops an animation, so pump a fixed time instead of settling.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump(const Duration(seconds: 1));

    expect(toastCalls, isEmpty);
    expect(hapticTypes, <Object?>['HapticFeedbackType.lightImpact']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
