// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/setups/views/pages/upload_wall_screen.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress_common/flutter_image_compress_common.dart';
import 'package:flutter_image_compress_platform_interface/flutter_image_compress_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockRouter extends Mock implements StackRouter {}

class _RecordingAnalytics extends FakeAppAnalytics {
  final List<String> events = <String>[];

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event.eventName);
}

class _FakeFirestoreClient extends Fake implements FirestoreClient {
  late Completer<void> save;
  int writes = 0;

  @override
  Future<String> addDoc(String collection, Map<String, dynamic> data, {required String sourceTag}) async {
    writes++;
    await save.future;
    return 'saved-wall';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const functions = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
    StandardMessageCodec(),
  );
  late Directory directory;
  late File image;
  late _FakeFirestoreClient firestore;
  late _RecordingAnalytics analytics;
  late _MockRouter router;
  late List<String> toasts;
  late int deletedAssets;
  late bool popped;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    registerFallbackValue(const ReviewRoute());
    final previousCompressor = FlutterImageCompressPlatform.instance;
    FlutterImageCompressCommon.registerWith();
    addTearDown(() => FlutterImageCompressPlatform.instance = previousCompressor);
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prism-upload-test-');
    image = File('${directory.path}/wall.png');
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await image.writeAsBytes(bytes);
    firestore = _FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = app_constants.createGuestPrismUser();
    analytics = _RecordingAnalytics();
    AnalyticsRuntime.instance = analytics;
    router = _MockRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    deletedAssets = 0;
    popped = false;
    toasts = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_image_compress'), (_) async => bytes);
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    messenger.setMockDecodedMessageHandler<Object?>(functions, (message) async {
      final args = (message! as List<Object?>).single! as Map<Object?, Object?>;
      if (args['functionName'] == 'githubDeleteFile') {
        deletedAssets++;
        return <Object?>[null];
      }
      final params = args['parameters']! as Map<Object?, Object?>;
      return <Object?>[
        <String, Object?>{
          'content': <String, Object?>{'path': params['path'], 'sha': 'sha', 'download_url': 'image'},
        },
      ];
    });
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_image_compress'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockDecodedMessageHandler<Object?>(functions, null);
    await directory.delete(recursive: true);
  });

  Future<void> openUpload(WidgetTester tester) async {
    firestore.save = Completer<void>();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      StackRouterScope(
        controller: router,
        stateHash: 0,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(builder: (_) => UploadWallScreen(image: image, fromSetupRoute: false)),
                );
                popped = true;
              },
              child: const Text('Upload'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Upload'));
    await tester.runAsync(() async {
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (find.byType(FloatingActionButton).evaluate().isNotEmpty &&
            tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed != null) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed, isNotNull);
  }

  testWidgets('pending save blocks repeat taps and Back; success keeps image assets', (tester) async {
    await openUpload(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('Submitting...'), findsOneWidget);
    expect(tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(popped, isFalse);
    expect(deletedAssets, 0);
    expect(analytics.events, isEmpty);
    verifyNever(() => router.push(any()));

    firestore.save.complete();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(deletedAssets, 0);
    expect(firestore.writes, 1);
    expect(analytics.events, ['upload_wallpaper']);
    verify(() => router.push(const ReviewRoute())).called(1);
  });

  testWidgets('failed save stays on upload screen without success; leaving cleans assets', (tester) async {
    await openUpload(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    firestore.save.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(popped, isFalse);
    expect(UploadQuota.currentUploadsThisWeek(), 0);
    expect(analytics.events, isEmpty);
    expect(toasts, ['Submit failed. Try again.']);
    expect(tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed, isNotNull);
    verifyNever(() => router.push(any()));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(deletedAssets, 2);
  });

  testWidgets('quota rejection stays on upload screen without navigation or success analytics', (tester) async {
    for (var i = 0; i < UploadQuota.freeUploadsPerWeek; i++) {
      await UploadQuota.incrementWeeklyUploads();
    }
    await openUpload(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(popped, isFalse);
    expect(firestore.writes, 0);
    expect(analytics.events, isEmpty);
    expect(toasts, ['Free users can upload 3 wallpapers per week.']);
    verifyNever(() => router.push(any()));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(deletedAssets, 2);
  });
}
