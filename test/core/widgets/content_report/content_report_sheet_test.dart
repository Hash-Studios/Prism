// Firebase platform-interface packages are transitive, but these fakes need them.
// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/content_reports/content_report_repository.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../support/fake_app_analytics.dart';

class _NoMultiFactor extends MultiFactorPlatform {
  _NoMultiFactor(super.auth);
}

class _SignedInUser extends UserPlatform {
  _SignedInUser(FirebaseAuthPlatform auth)
    : super(
        auth,
        _NoMultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(uid: 'viewer-1', isAnonymous: false, isEmailVerified: true),
          providerData: const <Map<Object?, Object?>?>[],
        ),
      );
}

class _FakeAuth extends FirebaseAuthPlatform {
  bool signedIn = true;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform? get currentUser => signedIn ? _SignedInUser(this) : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reports implements ContentReportRepository {
  final List<({String type, String id, String reason, String details})> sent = [];

  @override
  Future<Result<void>> submitReport({
    required String contentType,
    required String targetFirestoreDocId,
    required String reason,
    String details = '',
    String appVersion = '',
  }) async {
    sent.add((type: contentType, id: targetFirestoreDocId, reason: reason, details: details));
    return Result.success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  final _FakeAuth auth = _FakeAuth();
  late FirebaseAuthPlatform previousAuth;
  late _Reports reports;
  late List<MethodCall> toasts;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    PackageInfo.setMockInitialValues(
      appName: 'Prism',
      packageName: 'com.hash.prism',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    previousAuth = FirebaseAuthPlatform.instance;
    FirebaseAuthPlatform.instance = auth;
  });

  tearDownAll(() => FirebaseAuthPlatform.instance = previousAuth);

  setUp(() {
    reports = _Reports();
    getIt.registerSingleton<ContentReportRepository>(reports);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    toasts = <MethodCall>[];
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      toasts.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
  });

  Future<void> open(WidgetTester tester, {VoidCallback? onBlockCreator, bool signedIn = true}) async {
    auth.signedIn = signedIn;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showContentReportSheet(
                context,
                contentType: 'wall',
                targetFirestoreDocId: 'wall-doc',
                subtitle: 'ABC123',
                onBlockCreator: onBlockCreator,
              ),
              child: const Text('report'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('report'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Spam or misleading'));
    await tester.pump();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
  }

  testWidgets('the title and the wall id use the shared text styles, not hard-coded sizes', (tester) async {
    await open(tester);

    final TextStyle? title = tester.widget<Text>(find.text('Report wallpaper')).style;
    final TextStyle? subtitle = tester.widget<Text>(find.text('ABC123')).style;
    expect((title?.fontSize, title?.fontWeight), (16, FontWeight.w700));
    expect((subtitle?.fontSize, subtitle?.fontWeight), (14, FontWeight.w500));
  });

  testWidgets('after Report sent the snackbar offers Also block this creator', (tester) async {
    int blocked = 0;
    await open(tester, onBlockCreator: () => blocked++);

    await submit(tester);

    expect(reports.sent.single.reason, 'spam');
    expect(reports.sent.single.id, 'wall-doc');
    expect(find.text('Report sent. Thank you.'), findsOneWidget);
    await tester.tap(find.text('Also block this creator'));
    await tester.pump();
    expect(blocked, 1);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('without a block action the report ends with the plain toast', (tester) async {
    await open(tester);

    await submit(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(
      toasts.any((call) => call.method == 'showToast' && (call.arguments as Map)['msg'] == 'Report sent. Thank you.'),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a guest gets the sign-in sheet, not only a toast', (tester) async {
    await open(tester, signedIn: false);

    expect(find.text('Signing in unlocks'), findsOneWidget);
    expect(
      toasts.any((call) => call.method == 'showToast' && (call.arguments as Map)['msg'] == 'Sign in to report content'),
      isTrue,
    );
    expect(find.text('Submit report'), findsNothing);
    expect(reports.sent, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });
}
