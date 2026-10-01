// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedOutFirebaseAuthPlatform extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({PigeonUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform? get currentUser => null;

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

  testWidgets('a signed-out report attempt only gets the blocked-action error haptic', (tester) async {
    final FirebaseAuthPlatform previousPlatform = FirebaseAuthPlatform.instance;
    FirebaseAuthPlatform.instance = _SignedOutFirebaseAuthPlatform();
    addTearDown(() => FirebaseAuthPlatform.instance = previousPlatform);
    final List<Object?> hapticTypes = <Object?>[];
    final List<MethodCall> toastCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      toastCalls.add(call);
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(toastChannel, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showContentReportSheet(context, contentType: 'wall', targetFirestoreDocId: 'wall-1'),
              child: const Text('Report'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(hapticTypes, <Object?>['HapticFeedbackType.errorNotification']);
    expect(
      toastCalls.any((call) => (call.arguments as Map<Object?, Object?>)['msg'] == 'Sign in to report content'),
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
