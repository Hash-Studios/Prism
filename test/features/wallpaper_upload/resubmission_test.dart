import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/features/wallpaper_upload/biz/resubmission_cubit.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_session.dart';
import 'package:Prism/features/wallpaper_upload/data/resubmission_repository.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_submission_result.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/resubmit_wall_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/pending_image_picker.dart';
import '../../support/wait_for_real_io.dart';

class _Firestore extends Mock implements FirestoreClient {
  _Firestore(this.data);
  final Map<String, dynamic>? data;
  String? collection;
  String? tag;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    this.collection = collection;
    tag = sourceTag;
    return data == null ? null : map(data!, id);
  }
}

class _Cubit extends MockCubit<ResubmissionState> implements ResubmissionCubit {}

class _Router extends Mock implements StackRouter {}

class _DraftStore extends UploadDraftStore {
  @override
  Future<UploadDraft?> read({required String owner, required String draftId}) async => null;

  @override
  Future<UploadDraft> save({
    required String owner,
    required String draftId,
    required File selectedFile,
    required SubmissionMetadata metadata,
    UploadSession? session,
  }) async => UploadDraft(owner: owner, draftId: draftId, file: selectedFile, metadata: metadata, session: session);

  @override
  Future<void> discard({required String owner, required String draftId}) async {}
}

class _DefaultsStore extends LastSubmissionDefaultsStore {
  @override
  Future<void> save(String owner, SubmissionMetadata metadata) async {}
}

class _ResubmissionRouter extends AppRouter {
  _ResubmissionRouter(this.cubit, this.onSubmit);

  final ResubmissionCubit cubit;
  final VoidCallback onSubmit;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'HostRoute',
        builder: (data) => Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => context.router.push(ReviewRoute()), child: const Text('Your uploads')),
          ),
        ),
      ),
    ),
    AutoRoute(
      path: '/review',
      page: PageInfo(
        ReviewRoute.name,
        builder: (data) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ResubmitWallScreen(rejectedDocId: 'rejected-1', cubit: cubit),
                ),
              ),
              child: const Text('Fix and resubmit'),
            ),
          ),
        ),
      ),
    ),
    AutoRoute(
      path: '/upload-wall',
      page: PageInfo(
        UploadWallRoute.name,
        builder: (data) {
          final args = data.argsAs<UploadWallRouteArgs>();
          return UploadWallScreen(
            image: args.image,
            resubmission: args.resubmission,
            prepareImageForTesting: () async {},
            draftStoreForTesting: _DraftStore(),
            defaultsStoreForTesting: _DefaultsStore(),
            uploadFileForTesting: ({required isThumbnail}) async =>
                const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'wall.png', sha: 'sha'),
            createRecordForTesting: () async {
              onSubmit();
              return WallSubmissionResult.submitted;
            },
          );
        },
      ),
    ),
  ];
}

void main() {
  const seed = ResubmissionSeed(
    rejectedDocId: 'rejected-1',
    previousReason: 'Please remove the border',
    metadata: SubmissionMetadata(title: 'Dunes', description: 'At sunset', category: 'Nature', tags: ['sand']),
  );

  setUpAll(() => registerFallbackValue(UploadWallRoute(image: File('/tmp/original.jpg'))));

  for (final field in ['Title', 'Description']) {
    for (final action in ['Save', 'Choose image']) {
      testWidgets('resubmit releases $field focus before $action', (tester) async {
        tester.view.physicalSize = const Size(500, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cubit = _Cubit();
        when(() => cubit.uid).thenReturn(app_state.prismUser.id);
        when(() => cubit.state).thenReturn(
          ResubmissionState(
            loading: false,
            preparation: ResubmissionPreparation(seed: seed, original: File('/tmp/original.jpg')),
          ),
        );
        final router = _Router();
        // Keep the form mounted so route focus handling cannot hide a missing unfocus.
        when(() => router.push(any())).thenAnswer((_) async => null);
        final previousPicker = ImagePickerPlatform.instance;
        final picker = PendingImagePicker();
        ImagePickerPlatform.instance = picker;
        addTearDown(() => ImagePickerPlatform.instance = previousPicker);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: ResubmitWallScreen(rejectedDocId: 'rejected-1', cubit: cubit),
            ),
          ),
        );
        await tester.showKeyboard(find.widgetWithText(TextField, field));
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          tester.widgetList<EditableText>(find.byType(EditableText)).any((text) => text.focusNode.hasFocus),
          isTrue,
        );

        await tester.tap(find.text(action));
        await tester.pump();

        expect(
          tester.widgetList<EditableText>(find.byType(EditableText)).any((text) => text.focusNode.hasFocus),
          isFalse,
        );
        expect(tester.testTextInput.isVisible, isFalse);
        if (action == 'Save') {
          final route = verify(() => router.push(captureAny())).captured.single as UploadWallRoute;
          expect(route.args!.resubmission!.metadata.title, 'Dunes');
        } else {
          expect(picker.calls, 1);
          picker.finish([]);
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('successful resubmission returns to the existing review and Back skips the stale form', (tester) async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-resubmit-')))!;
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    final image = File('${directory.path}/original.jpg');
    await tester.runAsync(() => image.writeAsBytes([1, 2, 3]));
    final cubit = _Cubit();
    when(() => cubit.uid).thenReturn(app_state.prismUser.id);
    when(() => cubit.state).thenReturn(
      ResubmissionState(
        loading: false,
        preparation: ResubmissionPreparation(seed: seed, original: image),
      ),
    );
    var submissions = 0;
    final router = _ResubmissionRouter(cubit, () => submissions++);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your uploads'));
    await tester.pumpAndSettle();
    final originalReview = router.stackData.last;
    await tester.tap(find.text('Fix and resubmit'));
    await tester.pumpAndSettle();
    expect(find.text('Original image ready'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await waitForRealIo(
      tester,
      () => find.text('Ready to submit').evaluate().isNotEmpty,
      reason: 'prepare resubmission',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<UploadWallScreen>(find.byType(UploadWallScreen)).resubmission!.rejectedDocId, 'rejected-1');
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(submissions, 1);
    expect(find.text('Fix and resubmit'), findsOneWidget);
    expect(router.stackData.last, same(originalReview));
    expect(router.stackData.map((route) => route.name), ['HostRoute', ReviewRoute.name]);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your uploads'), findsOneWidget);
    expect(find.text('Original image ready'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(submissions, 1);
    expect(tester.takeException(), isNull);
  });

  test('owner gets metadata and a missing-image fallback when original URL is empty', () async {
    final client = _Firestore({
      'creatorUid': 'owner',
      'email': 'other@example.com',
      'wallpaper_url': '',
      'title': 'Dunes',
      'desc': 'At sunset',
      'category': 'Nature',
      'tags': ['sand', 2],
      'rejectionReason': 'Please remove the border',
    });
    final result = await ResubmissionRepository(client).prepare('rejected-1', uid: 'owner', email: 'owner@example.com');
    expect(client.collection, FirebaseCollections.rejectedWalls);
    expect(client.tag, 'upload.resubmit.prepare');
    expect(result.original, isNull);
    expect(result.unsupportedSource, isFalse);
    expect(result.seed.previousReason, 'Please remove the border');
    expect(result.seed.metadata.title, 'Dunes');
    expect(result.seed.metadata.description, 'At sunset');
    expect(result.seed.metadata.category, 'Nature');
    expect(result.seed.metadata.tags, ['sand']);
  });

  for (final source in [
    <String, dynamic>{'isAiGenerated': true},
    <String, dynamic>{'origin': 'studio'},
  ]) {
    test('unsupported source $source asks for a replacement image', () async {
      final client = _Firestore({
        'email': 'owner@example.com',
        'wallpaper_url': 'https://example.test/image',
        ...source,
      });
      final result = await ResubmissionRepository(
        client,
      ).prepare('rejected-1', uid: 'owner', email: 'owner@example.com');
      expect(result.unsupportedSource, isTrue);
      expect(result.original, isNull);
    });
  }

  test('a different owner cannot prepare a rejected upload even with matching email', () async {
    final client = _Firestore({'creatorUid': 'someone-else', 'email': 'owner@example.com'});
    await expectLater(
      ResubmissionRepository(client).prepare('rejected-1', uid: 'owner', email: 'owner@example.com'),
      throwsStateError,
    );
  });

  for (final hasImage in [true, false]) {
    testWidgets('resubmit displays prior feedback and details with image ${hasImage ? 'kept' : 'missing'}', (
      tester,
    ) async {
      final cubit = _Cubit();
      when(() => cubit.state).thenReturn(
        ResubmissionState(
          loading: false,
          preparation: ResubmissionPreparation(seed: seed, original: hasImage ? File('/tmp/original.jpg') : null),
        ),
      );
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResubmitWallScreen(rejectedDocId: 'rejected-1', cubit: cubit),
        ),
      );
      expect(find.text('Please remove the border'), findsOneWidget);
      expect(
        find.text(
          hasImage
              ? 'Original image ready'
              : 'The original image is no longer available. Choose it again to keep editing.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Title')).controller!.text, 'Dunes');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).controller!.text, 'At sunset');
      expect(find.widgetWithText(InputChip, 'sand'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Nature')).selected, isTrue);
      expect(find.text('Save'), hasImage ? findsOneWidget : findsNothing);
      expect(find.text('Choose image'), findsOneWidget);
    });
  }
}
