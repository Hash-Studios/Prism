import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/features/daily_flow/daily_moment_config.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/review_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

class _UploadFirestore extends CoinsTestFirestore {
  final List<Map<String, dynamic>> walls = <Map<String, dynamic>>[];

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async => walls.add(data);

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) =>
      Stream<List<T>>.value(<T>[]);
}

class _RecordingDefaultsStore extends LastSubmissionDefaultsStore {
  final owners = <String>[];

  @override
  Future<void> save(String owner, SubmissionMetadata metadata) async => owners.add(owner);
}

class _BatchAwardRouter extends AppRouter {
  _BatchAwardRouter(this.batch);

  final UploadBatch batch;
  final defaults = _RecordingDefaultsStore();

  UploadWallRoute upload() => UploadWallRoute(
    image: batch.current,
    batch: batch,
    defaultsStoreForTesting: defaults,
    prepareImageForTesting: () async {},
    uploadFileForTesting: ({required isThumbnail}) async => GitHubContent(
      downloadUrl: 'https://example.test/${isThumbnail ? 'thumb' : 'wall'}.png',
      path: '${isThumbnail ? 'thumb' : 'wall'}.png',
      sha: 'sha',
    ),
  );

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo(
        'BatchHost',
        builder: (_) => Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => context.router.push<Object?>(upload()), child: const Text('Open uploader')),
          ),
        ),
      ),
    ),
    AutoRoute(path: '/upload', page: UploadWallRoute.page),
    AutoRoute(
      path: '/edit',
      page: PageInfo(
        EditWallRoute.name,
        builder: (_) => Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => context.router.replace<Object?>(upload()), child: const Text('Next image')),
          ),
        ),
      ),
    ),
    AutoRoute(path: '/review', page: ReviewRoute.page),
  ];
}

void main() {
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.reset();
    DailyMomentConfig.enabledOverride = null;
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  for (final scenario in <String>['submit', 'skip', 'switch account', 'no confirmed award']) {
    testWidgets('batch preserves only the confirmed first-upload receipt on $scenario', (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
      AnalyticsRuntime.instance = FakeAppAnalytics();
      DailyMomentConfig.enabledOverride = true;
      final backend = CoinsTestBackend();
      await backend.install();
      app_state.prismUser.premium = true;
      final owner = app_state.prismUser.id;
      final firestore = _UploadFirestore();
      getIt.registerSingleton<FirestoreClient>(firestore);
      var awardCalls = 0;
      backend.onCall = (name, params) async {
        if (name == 'reconcileRankRewards') return <String, Object?>{'success': true};
        expect(name, 'awardCoins');
        expect(params['action'], 'firstWallpaperUpload');
        awardCalls++;
        final changed = awardCalls == 1 && scenario != 'no confirmed award';
        return <String, Object?>{
          'success': true,
          'changed': changed,
          'delta': changed ? 37 : 0,
          'previousBalance': 100,
          'currentBalance': 999,
        };
      };
      final batch = UploadBatch(<File>[File('first.png'), File('last.png')]);
      final router = _BatchAwardRouter(batch);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
        ),
      );
      await router.navigatePath('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open uploader'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('Next image'), findsOneWidget);
      expect(firestore.walls, hasLength(1));
      expect(awardCalls, 1);
      expect(router.defaults.owners, <String>[owner]);

      if (scenario == 'switch account') app_state.prismUser.id = 'another-account';
      await tester.tap(find.text('Next image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(scenario == 'skip' ? 'Skip this wallpaper' : 'Upload'));
      await tester.pumpAndSettle();

      final review = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
      final hasAward = scenario != 'no confirmed award';
      expect(review.earnedCoins, hasAward ? 37 : 0);
      expect(review.earnedCoinsOwnerId, hasAward ? owner : null);
      expect(awardCalls, scenario == 'skip' ? 1 : 2);
      expect(firestore.walls, hasLength(scenario == 'skip' ? 1 : 2));
      expect(router.defaults.owners, <String>[
        owner,
        if (scenario == 'switch account') 'another-account' else if (scenario != 'skip') owner,
      ]);
      expect(find.text('+37 coins'), hasAward && scenario != 'switch account' ? findsOneWidget : findsNothing);
      if (scenario == 'switch account') {
        app_state.prismUser.id = owner;
        tester.element(find.byType(ReviewScreen)).markNeedsBuild();
        await tester.pump();
        expect(find.text('+37 coins'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
