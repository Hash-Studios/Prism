import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/features/wallpaper_upload/biz/upload_session.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/features/wallpaper_upload/data/last_submission_defaults_store.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/wait_for_real_io.dart';

const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

class _FailingUploadDraftStore extends UploadDraftStore {
  @override
  Future<UploadDraft?> read({required String owner, required String draftId}) async => null;

  @override
  Future<UploadDraft> save({
    required String owner,
    required String draftId,
    required File selectedFile,
    required SubmissionMetadata metadata,
    UploadSession? session,
  }) async => throw StateError('disk full');
}

class _RecordingDraftStore extends UploadDraftStore {
  final List<String> reads = [];

  @override
  Future<void> discard({required String owner, required String draftId}) async {}

  @override
  Future<UploadDraft?> read({required String owner, required String draftId}) async {
    reads.add(draftId);
    return null;
  }

  @override
  Future<UploadDraft> save({
    required String owner,
    required String draftId,
    required File selectedFile,
    required SubmissionMetadata metadata,
    UploadSession? session,
  }) async => UploadDraft(owner: owner, draftId: draftId, file: selectedFile, metadata: metadata, session: session);
}

class _SessionDraftStore extends UploadDraftStore {
  UploadDraft? saved;
  final sessions = <UploadSession>[];

  @override
  Future<UploadDraft?> read({required String owner, required String draftId}) async => saved;

  @override
  Future<UploadDraft> save({
    required String owner,
    required String draftId,
    required File selectedFile,
    required SubmissionMetadata metadata,
    UploadSession? session,
  }) async {
    if (session != null) sessions.add(session);
    return saved = UploadDraft(
      owner: owner,
      draftId: draftId,
      file: selectedFile,
      metadata: metadata,
      session: session,
    );
  }

  @override
  Future<void> discard({required String owner, required String draftId}) async {}
}

class _Defaults extends LastSubmissionDefaultsStore {
  _Defaults({this.failSave = false});
  final bool failSave;

  @override
  Future<SubmissionMetadata?> read(String owner) async =>
      const SubmissionMetadata(category: 'Nature', tags: ['forest']);

  @override
  Future<void> save(String owner, SubmissionMetadata metadata) async {
    if (failSave) throw StateError('defaults disk failure');
  }
}

class _DirectUploadRouter extends AppRouter {
  _DirectUploadRouter(this.screen);
  final Widget screen;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('DirectUpload', builder: (_) => screen),
    ),
    AutoRoute(
      path: '/review',
      page: PageInfo(ReviewRoute.name, builder: (_) => const Scaffold(body: Text('review-stub'))),
    ),
  ];
}

class _DraftStoreFixture {
  const _DraftStoreFixture(this.root);

  final Directory root;

  UploadDraftStore open() => UploadDraftStore(
    store: DurableJsonStore('upload_screen_test', directory: Directory('${root.path}/records')),
    directory: Directory('${root.path}/files'),
  );
}

class _TestAppRouter extends AppRouter {
  _TestAppRouter(this.uploadRoute);

  final UploadWallRoute Function() uploadRoute;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('UploadRouteHost', builder: (_) => Scaffold(body: _UploadRouteHost(uploadRoute))),
    ),
    AutoRoute(path: '/upload-wall', page: UploadWallRoute.page),
    AutoRoute(
      path: '/review',
      page: PageInfo(ReviewRoute.name, builder: (_) => const Scaffold(body: Text('review-stub'))),
    ),
  ];
}

class _UploadRouteHost extends StatelessWidget {
  const _UploadRouteHost(this.uploadRoute);

  final UploadWallRoute Function() uploadRoute;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => context.router.push<Object?>(uploadRoute()), child: const Text('Open uploader'));
}

/// Opens [route] from a host page inside a real [AppRouter], so a successful submit can push [ReviewRoute].
Future<void> pumpRoutedUpload(WidgetTester tester, UploadWallRoute Function() route) async {
  final router = _TestAppRouter(route);
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
}

void main() {
  setUp(AnalyticsRuntime.reset);
  tearDown(AnalyticsRuntime.reset);

  Future<File> makeImage(WidgetTester tester) async {
    final tempDirectory = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-upload-wall-')))!;
    addTearDown(() => tester.runAsync(() => tempDirectory.delete(recursive: true)));
    final image = File('${tempDirectory.path}/pixel.png');
    await tester.runAsync(
      () => image.writeAsBytes(
        base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC'),
      ),
    );
    return image;
  }

  Future<void> setViewport(WidgetTester tester) async {
    // Glint and the step spinner loop forever, so these tests run with motion off.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(360, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpImagePreparation(WidgetTester tester) async {
    await waitForRealIo(
      tester,
      () =>
          find.text('Ready to submit').evaluate().isNotEmpty ||
          find.text('Image could not be prepared').evaluate().isNotEmpty,
      reason: 'upload image preparation',
      pumpDuration: const Duration(milliseconds: 16),
    );
  }

  Future<T> waitForStoreOperation<T>(WidgetTester tester, Future<T> operation, {required String reason}) async {
    final Completer<T> result = Completer<T>();
    operation.then(
      result.complete,
      onError: (Object error, StackTrace stackTrace) => result.completeError(error, stackTrace),
    );
    await waitForRealIo(tester, () => result.isCompleted, reason: reason);
    return result.future;
  }

  Future<_DraftStoreFixture> makeDraftStore(WidgetTester tester) async {
    final Directory root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('prism-upload-screen-draft-'),
    ))!;
    addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
    return _DraftStoreFixture(root);
  }

  testWidgets('last details change only category and tags and a defaults write failure does not fail submission', (
    tester,
  ) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final drafts = _RecordingDraftStore();
    SubmissionMetadata? submitted;
    final resumed = UploadDraft(
      owner: UploadDraftStore.guestOwner,
      draftId: 'resume',
      file: image,
      metadata: const SubmissionMetadata(
        title: 'Personal title',
        description: 'Personal description',
        category: 'General',
        tags: ['old'],
        requestId: 'request-1',
        requestText: 'A requested wall',
      ),
      session: const UploadSession(
        operationId: 'operation-1',
        logicalId: 'wall-1',
        rejectedDocId: 'rejected-1',
        previousReason: 'Fix the border',
      ),
    );
    final router = _DirectUploadRouter(
      UploadWallScreen(
        image: image,
        resumedDraft: resumed,
        prepareImageForTesting: () async {},
        draftStoreForTesting: drafts,
        defaultsStoreForTesting: _Defaults(failSave: true),
        uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
            ? const GitHubContent(downloadUrl: 'https://example.test/t', path: 'thumb', sha: 't')
            : const GitHubContent(downloadUrl: 'https://example.test/w', path: 'wall', sha: 'w'),
        createRecordWithMetadataForTesting: ({required id, required metadata}) async {
          expect(id, 'wall-1');
          submitted = metadata;
          return wall_store.WallSubmissionResult.submitted;
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await waitForRealIo(
      tester,
      () => find.text('Ready to submit').evaluate().isNotEmpty,
      reason: 'prepare resumed upload',
    );
    await tester.ensureVisible(find.text('Use last details'));
    await tester.tap(find.text('Use last details'));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Title')).controller!.text, 'Personal title');
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).controller!.text,
      'Personal description',
    );
    expect(find.text('Fix the border'), findsOneWidget);
    await tester.ensureVisible(find.text('Upload'));
    await tester.tap(find.text('Upload'));
    await waitForRealIo(tester, () => submitted != null, reason: 'submit metadata');
    await tester.pumpAndSettle();
    expect(submitted!.title, 'Personal title');
    expect(submitted!.description, 'Personal description');
    expect(submitted!.category, 'Nature');
    expect(submitted!.tags, ['forest']);
    expect(submitted!.requestId, 'request-1');
    expect(submitted!.requestText, 'A requested wall');
    expect(find.text('Retry submit'), findsNothing);
    expect(find.text('review-stub'), findsOneWidget);
  });

  testWidgets('response loss preserves operation and file receipts across restart', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final drafts = _SessionDraftStore();
    var uploads = 0;
    var submissions = 0;
    Widget screen({UploadDraft? resumed}) => UploadWallScreen(
      image: image,
      resumedDraft: resumed,
      resubmission: const ResubmissionSeed(
        rejectedDocId: 'rejected-1',
        previousReason: 'Fix border',
        metadata: SubmissionMetadata(title: 'Dunes'),
      ),
      prepareImageForTesting: () async {},
      draftStoreForTesting: drafts,
      defaultsStoreForTesting: _Defaults(),
      uploadFileForTesting: ({required isThumbnail}) async {
        uploads++;
        return isThumbnail
            ? const GitHubContent(downloadUrl: 'https://example.test/t', path: 'thumb', sha: 't')
            : const GitHubContent(downloadUrl: 'https://example.test/w', path: 'wall', sha: 'w');
      },
      createRecordWithMetadataForTesting: ({required id, required metadata}) async {
        submissions++;
        if (submissions == 1) throw StateError('response lost');
        return wall_store.WallSubmissionResult.submitted;
      },
    );
    Future<void> open(Widget child) async {
      final router = _DirectUploadRouter(child);
      await tester.pumpWidget(
        MaterialApp.router(
          key: UniqueKey(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
        ),
      );
    }

    await open(screen());
    await waitForRealIo(
      tester,
      () => find.text('Ready to submit').evaluate().isNotEmpty,
      reason: 'prepare first attempt',
    );
    await tester.tap(find.text('Upload'));
    await waitForRealIo(tester, () => find.text('Retry submit').evaluate().isNotEmpty, reason: 'first response lost');
    final saved = drafts.saved!;
    final first = saved.session!;
    expect(first.submissionAttempted, isTrue);
    expect(first.rejectedDocId, 'rejected-1');
    expect(first.original!.path, 'wall');
    expect(first.thumbnail!.path, 'thumb');
    expect(uploads, 2);
    await open(screen(resumed: saved));
    await waitForRealIo(
      tester,
      () => find.text('Retry submit').evaluate().isNotEmpty,
      reason: 'restore unresolved attempt',
    );
    await tester.ensureVisible(find.text('Retry submit'));
    await tester.tap(find.text('Retry submit'));
    await waitForRealIo(tester, () => submissions == 2, reason: 'retry saved attempt');
    await tester.pumpAndSettle();
    expect(uploads, 2);
    final retry = drafts.sessions.last;
    expect(retry.operationId, first.operationId);
    expect(retry.logicalId, first.logicalId);
    expect(retry.rejectedDocId, first.rejectedDocId);
    expect(retry.original!.sha, first.original!.sha);
    expect(retry.thumbnail!.sha, first.thumbnail!.sha);
    expect(find.text('review-stub'), findsOneWidget);
  });

  testWidgets('identical image bytes use separate drafts for separate rejected submissions', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final drafts = _RecordingDraftStore();
    for (final rejectedId in ['rejected-a', 'rejected-b']) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UploadWallScreen(
            key: ValueKey(rejectedId),
            image: image,
            resubmission: ResubmissionSeed(
              rejectedDocId: rejectedId,
              previousReason: '',
              metadata: const SubmissionMetadata(),
            ),
            prepareImageForTesting: () async {},
            draftStoreForTesting: drafts,
          ),
        ),
      );
      await waitForRealIo(
        tester,
        () => drafts.reads.length == (rejectedId == 'rejected-a' ? 1 : 2),
        reason: 'read lineage-specific draft',
      );
      await tester.pump();
    }
    expect(drafts.reads[0], isNot(drafts.reads[1]));
  });

  testWidgets('explicit resumed draft takes precedence over resubmission seed', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final drafts = _RecordingDraftStore();
    final resumed = UploadDraft(
      owner: UploadDraftStore.guestOwner,
      draftId: 'saved-draft',
      file: image,
      metadata: const SubmissionMetadata(title: 'Draft title', description: 'Draft description', tags: ['draft']),
      session: const UploadSession(
        operationId: 'saved-operation',
        logicalId: 'saved-wall',
        rejectedDocId: 'saved-rejection',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UploadWallScreen(
          image: image,
          resumedDraft: resumed,
          resubmission: const ResubmissionSeed(
            rejectedDocId: 'other-rejection',
            previousReason: '',
            metadata: SubmissionMetadata(title: 'Seed title', description: 'Seed description'),
          ),
          prepareImageForTesting: () async {},
          draftStoreForTesting: drafts,
        ),
      ),
    );
    await waitForRealIo(
      tester,
      () => find.text('Ready to submit').evaluate().isNotEmpty,
      reason: 'resume upload draft',
    );
    await tester.ensureVisible(find.widgetWithText(TextField, 'Title'));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Title')).controller!.text, 'Draft title');
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).controller!.text,
      'Draft description',
    );
    expect(drafts.reads, ['saved-draft']);
  });

  testWidgets('restores a draft and discards only the current owner draft', (tester) async {
    await setViewport(tester);
    final File image = await makeImage(tester);
    final _DraftStoreFixture fixture = await makeDraftStore(tester);
    UploadDraftStore drafts = fixture.open();
    final String draftId = (await tester.runAsync(() async => UploadDraftStore.idForBytes(await image.readAsBytes())))!;

    Widget uploader() =>
        UploadWallScreen(image: image, prepareImageForTesting: () async {}, draftStoreForTesting: drafts);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => uploader())),
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await waitForRealIo(
      tester,
      () => find.text('Ready to submit').evaluate().isNotEmpty,
      reason: 'initial upload draft read and image preparation',
      pumpDuration: const Duration(milliseconds: 16),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Northern lights');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave this upload?'), findsOneWidget);
    await tester.tap(find.text('Keep draft'));
    await waitForRealIo(
      tester,
      () => find.text('Upload wallpaper').evaluate().isEmpty,
      reason: 'draft save and normal exit',
      pumpDuration: const Duration(milliseconds: 16),
    );
    expect(find.text('Upload wallpaper'), findsNothing);

    drafts = fixture.open();
    await tester.tap(find.text('Open uploader'));
    await waitForRealIo(
      tester,
      () => find.text('Ready to submit').evaluate().isNotEmpty,
      reason: 'reopened upload draft read and image preparation',
      pumpDuration: const Duration(milliseconds: 16),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.byType(TextField).first);

    final UploadDraft? restored = await waitForStoreOperation(
      tester,
      drafts.read(owner: UploadDraftStore.guestOwner, draftId: draftId),
      reason: 'verify persisted upload draft',
    );
    expect(restored?.metadata.title, 'Northern lights');
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'Northern lights');
    expect(await tester.runAsync(restored!.file.exists), isTrue);

    await waitForStoreOperation(
      tester,
      drafts.save(
        owner: 'another-account',
        draftId: draftId,
        selectedFile: image,
        metadata: const SubmissionMetadata(title: 'Other owner draft'),
      ),
      reason: 'seed other owner draft',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await waitForRealIo(
      tester,
      () => find.text('Upload wallpaper').evaluate().isEmpty,
      reason: 'draft discard and normal exit',
      pumpDuration: const Duration(milliseconds: 16),
    );
    expect(
      await waitForStoreOperation(
        tester,
        drafts.read(owner: UploadDraftStore.guestOwner, draftId: draftId),
        reason: 'verify discarded guest draft',
      ),
      isNull,
    );
    expect(
      (await waitForStoreOperation(
        tester,
        drafts.read(owner: 'another-account', draftId: draftId),
        reason: 'verify other owner draft remains',
      ))?.metadata.title,
      'Other owner draft',
    );
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays on the screen when keeping a draft fails to persist', (tester) async {
    await setViewport(tester);
    final File image = await makeImage(tester);
    final messages = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, (call) async {
      if (call.method == 'showToast') messages.add((call.arguments as Map<Object?, Object?>)['msg'] as String?);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          draftStoreForTesting: _FailingUploadDraftStore(),
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep draft'));
    await tester.pumpAndSettle();

    expect(find.text('Upload wallpaper'), findsOneWidget);
    expect(find.text('Leave this upload?'), findsNothing);
    expect(messages, <String?>['Could not save this draft. Try again.']);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('prepares locally, blocks duplicate taps while busy, then opens review status', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final fullUpload = Completer<GitHubContent>();
    final save = Completer<wall_store.WallSubmissionResult>();
    var uploadCalls = 0;
    var saveCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) {
          uploadCalls++;
          if (isThumbnail) {
            return Future.value(
              const GitHubContent(
                downloadUrl: 'https://example.test/thumb.png',
                path: 'thumb_pixel.png',
                sha: 'thumb-sha',
              ),
            );
          }
          return fullUpload.future;
        },
        createRecordForTesting: () {
          saveCalls++;
          return save.future;
        },
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ready to submit'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(uploadCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Upload'));
    await tester.pump();
    expect(find.text('Uploading wallpaper'), findsOneWidget);
    await tester.tap(find.byType(PrismButton), warnIfMissed: false);
    await tester.pump();
    expect(uploadCalls, 1);
    expect(saveCalls, 0);

    fullUpload.complete(
      const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Submitting wallpaper'), findsOneWidget);
    expect(saveCalls, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Submitting wallpaper'), findsOneWidget);

    save.complete(wall_store.WallSubmissionResult.submitted);
    await tester.pumpAndSettle();
    expect(find.text('review-stub'), findsOneWidget);
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracks a confirmed upload once when the screen was popped while saving', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final save = Completer<wall_store.WallSubmissionResult>();
    final recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => UploadWallScreen(
                    image: image,
                    prepareImageForTesting: () async {},
                    uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
                        ? const GitHubContent(
                            downloadUrl: 'https://example.test/thumb.png',
                            path: 'thumb_pixel.png',
                            sha: 'thumb-sha',
                          )
                        : const GitHubContent(
                            downloadUrl: 'https://example.test/wall.png',
                            path: 'pixel.png',
                            sha: 'wall-sha',
                          ),
                    createRecordForTesting: () => save.future,
                  ),
                ),
              ),
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await tester.pump(const Duration(milliseconds: 400));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Submitting wallpaper'), findsOneWidget);

    Navigator.of(tester.element(find.text('Submitting wallpaper'))).pop();
    await tester.pumpAndSettle();
    save.complete(wall_store.WallSubmissionResult.submitted);
    await tester.pump();

    final uploads = recorder.events.whereType<UploadWallpaperEvent>().toList();
    expect(uploads, hasLength(1));
    expect(uploads.single.assetId, isNotEmpty);
    expect(uploads.single.link, 'https://example.test/wall.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a confirmed submit closes the uploader and opens review status', (tester) async {
    await setViewport(tester);
    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: File('test-image.png'),
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
            ? const GitHubContent(
                downloadUrl: 'https://example.test/thumb.png',
                path: 'thumb_test-image.png',
                sha: 'thumb-sha',
              )
            : const GitHubContent(
                downloadUrl: 'https://example.test/wall.png',
                path: 'test-image.png',
                sha: 'wall-sha',
              ),
        createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('review-stub'), findsOneWidget);
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upload button plays one tap haptic and uploads both image files', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final List<String> haptics = <String>[];
    final bool previousHapticsEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    addTearDown(() => PrismHaptics.enabled = previousHapticsEnabled);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final List<bool> uploadedThumbnails = <bool>[];
    var saveCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async {
          uploadedThumbnails.add(isThumbnail);
          return isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha');
        },
        createRecordForTesting: () async {
          saveCalls++;
          return wall_store.WallSubmissionResult.submitted;
        },
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(uploadedThumbnails, <bool>[false, true]);
    expect(saveCalls, 1);
    expect(haptics, <String>['HapticFeedbackType.lightImpact']);
    expect(find.text('review-stub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('stage title has readable contrast in every legacy theme', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final themes = <ThemeData>[
      kLightTheme,
      kLightTheme2,
      kLightTheme3,
      kLightTheme4,
      kDarkTheme,
      kDarkTheme2,
      kDarkTheme3,
      kDarkTheme4,
      kDarkTheme5,
      kDarkTheme6,
      kDarkTheme7,
      kDarkTheme8,
    ];

    for (final theme in themes) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: UploadWallScreen(image: image, prepareImageForTesting: () async {}),
        ),
      );
      await pumpImagePreparation(tester);

      final titleFinder = find.text('Ready to submit');
      final effectiveTheme = Theme.of(tester.element(titleFinder));
      final titleColor = tester.widget<Text>(titleFinder).style!.color!;
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final scaffoldBackground = scaffold.backgroundColor ?? effectiveTheme.scaffoldBackgroundColor;
      expect(_contrastRatio(titleColor, scaffoldBackground), greaterThanOrEqualTo(4.5));
      expect(titleColor, effectiveTheme.colorScheme.onSurface);
    }
  });

  testWidgets('cancel sends exact server source kinds independently of download URLs', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final backend = CoinsTestBackend();
    final oldUser = app_state.prismUser;
    await backend.install();
    addTearDown(() async {
      app_state.prismUser = oldUser;
      await getIt.reset();
    });
    final deletedFiles = <Map<String, dynamic>>[];
    final deletedFunctions = <String>[];
    backend.onCall = (name, parameters) async {
      deletedFunctions.add(name);
      deletedFiles.add(parameters);
      return <String, dynamic>{'ok': true};
    };
    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async => GitHubContent.fromData(<String, dynamic>{
          'sourceKind': isThumbnail ? 'github' : 'owned',
          'content': <String, dynamic>{
            'path': isThumbnail ? 'thumb.png' : 'private.png',
            'sha': isThumbnail ? 'thumb-sha' : 'private-sha',
            'download_url': isThumbnail ? null : '',
          },
        }),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deletedFiles.map((file) => file['sourceKind']), <String>['owned', 'github']);
    expect(deletedFiles.map((file) => file['path']), <String>['private.png', 'thumb.png']);
    expect(deletedFunctions, <String>['githubDeleteFile', 'githubDeleteFile']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a weekly quota result without retrying a save', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    var saveCalls = 0;
    final deletedFiles = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
          deleteFileForTesting: ({required path, required sha}) async {
            deletedFiles.add(path);
          },
          createRecordForTesting: () async {
            saveCalls++;
            return wall_store.WallSubmissionResult.quotaExceeded;
          },
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Upload limit reached'), findsOneWidget);
    expect(find.text('You have reached this week’s free wallpaper upload limit.'), findsOneWidget);
    expect(saveCalls, 1);
    expect(deletedFiles, ['pixel.png', 'thumb_pixel.png']);
    expect(recorder.events.whereType<UploadWallpaperEvent>(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps uploaded files when a retry after an unconfirmed save reports the quota', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var saveCalls = 0;
    final deletedFiles = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
          deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
          createRecordForTesting: () async {
            saveCalls++;
            if (saveCalls == 1) throw StateError('network response was lost');
            return wall_store.WallSubmissionResult.quotaExceeded;
          },
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Retry submit'), findsOneWidget);

    await tester.ensureVisible(find.text('Retry submit'));
    await tester.tap(find.text('Retry submit'));
    await tester.pumpAndSettle();

    expect(saveCalls, 2);
    expect(deletedFiles, isEmpty);
    expect(find.text('Submission did not finish'), findsOneWidget);
    expect(find.text('Upload limit reached'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the quota screen open when file cleanup fails and lets Back retry cleanup', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
          deleteFileForTesting: ({required path, required sha}) async {
            deleteCalls++;
            if (deleteCalls <= 2) throw StateError('temporary cleanup failure');
          },
          createRecordForTesting: () async => wall_store.WallSubmissionResult.quotaExceeded,
        ),
      ),
    );
    await pumpImagePreparation(tester);
    final toastMessages = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, (call) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg'] as String?);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, null));
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Back'));
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Upload limit reached'), findsOneWidget);
    expect(toastMessages, <String?>['Could not remove uploaded files. Try again.']);
    await tester.ensureVisible(find.text('Back'));
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Upload limit reached'), findsNothing);
    expect(deleteCalls, 4);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('keeps an uncertain save visible and offers status check and a safe retry', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
          createRecordForTesting: () {
            saveCalls++;
            return Future<wall_store.WallSubmissionResult>.error(StateError('network response was lost'));
          },
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Submission did not finish'), findsOneWidget);
    expect(find.text('Check review status'), findsOneWidget);
    expect(find.text('Retry submit'), findsOneWidget);
    expect(saveCalls, 1);
    expect(recorder.events.whereType<UploadWallpaperEvent>(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes the wallpaper when thumbnail upload fails after the screen is removed', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final thumbnailUpload = Completer<GitHubContent>();
    final deletedFiles = <String>[];
    var uploadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) {
            uploadCalls++;
            return isThumbnail
                ? thumbnailUpload.future
                : Future.value(
                    const GitHubContent(
                      downloadUrl: 'https://example.test/wall.png',
                      path: 'pixel.png',
                      sha: 'wall-sha',
                    ),
                  );
          },
          deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
          createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump();
    expect(uploadCalls, 2);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(),
      ),
    );
    thumbnailUpload.completeError(StateError('request failed'));
    await tester.pump();
    await tester.pump();

    expect(deletedFiles, ['pixel.png']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes staged files when the idle screen is removed externally', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async {
            if (isThumbnail) throw StateError('preview upload failed');
            return const GitHubContent(
              downloadUrl: 'https://example.test/wall.png',
              path: 'pixel.png',
              sha: 'wall-sha',
            );
          },
          deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload did not finish'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(),
      ),
    );
    await tester.pump();
    expect(deletedFiles, ['pixel.png']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps partial GitHub file details so discard can remove an incomplete upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) async =>
                          const GitHubContent(downloadUrl: null, path: 'pixel.png', sha: 'wall-sha'),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deletedFiles, ['pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cleans an incomplete GitHub file before retrying its upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    var wallpaperCalls = 0;
    var thumbnailCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async {
          if (isThumbnail) {
            thumbnailCalls++;
            return const GitHubContent(
              downloadUrl: 'https://example.test/thumb.png',
              path: 'thumb_pixel.png',
              sha: 'thumb-sha',
            );
          }
          wallpaperCalls++;
          return GitHubContent(
            downloadUrl: wallpaperCalls == 1 ? null : 'https://example.test/wall.png',
            path: 'pixel.png',
            sha: 'wall-sha-$wallpaperCalls',
          );
        },
        deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
        createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(wallpaperCalls, 2);
    expect(thumbnailCalls, 1);
    expect(deletedFiles, ['pixel.png']);
    expect(find.text('Submission did not finish'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reuses the wallpaper and retries only the failed thumbnail upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final List<String> haptics = <String>[];
    final bool previousHapticsEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    addTearDown(() => PrismHaptics.enabled = previousHapticsEnabled);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    var wallpaperCalls = 0;
    var thumbnailCalls = 0;
    var saveCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async {
          if (isThumbnail) {
            thumbnailCalls++;
            if (thumbnailCalls == 1) throw StateError('temporary preview failure');
            return const GitHubContent(
              downloadUrl: 'https://example.test/thumb.png',
              path: 'thumb_pixel.png',
              sha: 'thumb-sha',
            );
          }
          wallpaperCalls++;
          return const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha');
        },
        createRecordForTesting: () async {
          saveCalls++;
          return wall_store.WallSubmissionResult.submitted;
        },
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload did not finish'), findsOneWidget);
    expect(haptics, <String>['HapticFeedbackType.lightImpact']);

    haptics.clear();
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(haptics, <String>['HapticFeedbackType.lightImpact']);

    expect(wallpaperCalls, 1);
    expect(thumbnailCalls, 2);
    expect(saveCalls, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('uses the requested path to discard a response missing URL and path', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      nowForTesting: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
                      uploadFileForTesting: ({required isThumbnail}) async =>
                          const GitHubContent(downloadUrl: null, path: null, sha: 'wall-sha'),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deletedFiles, ['${app_state.prismUser.id}_1700000000000_pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the thumbnail path to discard a response missing URL and path', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      nowForTesting: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
                      uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
                          ? const GitHubContent(downloadUrl: null, path: null, sha: 'thumb-sha')
                          : const GitHubContent(
                              downloadUrl: 'https://example.test/wall.png',
                              path: 'pixel.png',
                              sha: 'wall-sha',
                            ),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deletedFiles, ['pixel.png', 'thumb_${app_state.prismUser.id}_1700000000000_pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not restart an incomplete upload after direct pop during cleanup', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final cleanup = Completer<void>();
    var uploadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) async {
                        uploadCalls++;
                        return const GitHubContent(downloadUrl: null, path: 'pixel.png', sha: 'wall-sha');
                      },
                      deleteFileForTesting: ({required path, required sha}) => cleanup.future,
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(uploadCalls, 1);

    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pump();
    Navigator.of(tester.element(find.text('Uploading wallpaper'))).pop();
    await tester.pump(const Duration(milliseconds: 10));
    cleanup.complete();
    await tester.pumpAndSettle();

    expect(uploadCalls, 1);
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancels submission and removes both files when directly popped during thumbnail upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final thumbnailUpload = Completer<GitHubContent>();
    final deletedFiles = <String>[];
    var saveCalls = 0;
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) => isThumbnail
                          ? thumbnailUpload.future
                          : Future.value(
                              const GitHubContent(
                                downloadUrl: 'https://example.test/wall.png',
                                path: 'pixel.png',
                                sha: 'wall-sha',
                              ),
                            ),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                      createRecordForTesting: () async {
                        saveCalls++;
                        return wall_store.WallSubmissionResult.submitted;
                      },
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Uploading wallpaper'), findsOneWidget);

    Navigator.of(tester.element(find.text('Uploading wallpaper'))).pop();
    await tester.pump(const Duration(milliseconds: 10));
    thumbnailUpload.complete(
      const GitHubContent(downloadUrl: 'https://example.test/thumb.png', path: 'thumb_pixel.png', sha: 'thumb-sha'),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(deletedFiles, ['pixel.png', 'thumb_pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready state shows the preview facts, the checklist and one Upload button', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(image: image, prepareImageForTesting: () async {}),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();

    expect(find.text('Upload wallpaper'), findsOneWidget);
    expect(find.text('Resolution'), findsOneWidget);
    expect(find.text('1 x 1'), findsOneWidget);
    expect(find.text('Size'), findsOneWidget);
    expect(find.text('0.00 MB'), findsOneWidget);
    expect(find.text('Ready to submit'), findsOneWidget);
    expect(find.text('Image and preview are ready'), findsOneWidget);
    expect(find.text('Upload the wallpaper and its preview'), findsOneWidget);
    expect(find.text('Moderators review it before it appears in Prism'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Upload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('while uploading, the button shows a spinner and the active step is named', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final fullUpload = Completer<GitHubContent>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) => fullUpload.future,
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();

    expect(find.text('Uploading wallpaper'), findsOneWidget);
    expect(find.text('Uploading the wallpaper and its preview'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).loading, isTrue);
    fullUpload.completeError(StateError('stop'));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('an image that cannot be prepared shows the reason and a retry', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final List<String> haptics = <String>[];
    final bool previousHapticsEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    addTearDown(() => PrismHaptics.enabled = previousHapticsEnabled);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {
            if (attempts++ == 0) throw StateError('decode failed');
          },
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();

    expect(find.text('Image could not be prepared'), findsOneWidget);
    expect(find.text('We could not prepare this image. Try again or choose another image.'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Upload'), findsNothing);

    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    expect(haptics, <String>['HapticFeedbackType.lightImpact']);

    expect(attempts, 2);
    expect(find.text('Ready to submit'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets('Retry submit reuses the uploaded files and submits once the save works', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final List<String> haptics = <String>[];
    final bool previousHapticsEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    addTearDown(() => PrismHaptics.enabled = previousHapticsEnabled);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    var uploadCalls = 0;
    var saveCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async {
          uploadCalls++;
          return isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha');
        },
        createRecordForTesting: () async {
          if (saveCalls++ == 0) throw StateError('network response was lost');
          return wall_store.WallSubmissionResult.submitted;
        },
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Retry submit'), findsOneWidget);
    expect(uploadCalls, 2);
    expect(haptics, <String>['HapticFeedbackType.lightImpact']);

    haptics.clear();
    await tester.ensureVisible(find.text('Retry submit'));
    await tester.tap(find.text('Retry submit'));
    await tester.pumpAndSettle();

    expect(haptics, <String>['HapticFeedbackType.lightImpact']);
    expect(saveCalls, 2);
    expect(uploadCalls, 2);
    expect(find.text('review-stub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a weekly limit error from the server explains it and shows the paywall', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var paywalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => throw FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: 'Free weekly wallpaper upload limit reached.',
          ),
          presentPaywallForTesting: () async => paywalls++,
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Upload did not finish'), findsOneWidget);
    expect(find.text('You reached this week’s free upload limit.'), findsOneWidget);
    expect(paywalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a too large server error shows its own message without the paywall', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var paywalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async =>
              throw FirebaseFunctionsException(code: 'invalid-argument', message: 'File is too large.'),
          presentPaywallForTesting: () async => paywalls++,
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('This image is over 15 MB. Choose a smaller one.'), findsOneWidget);
    expect(paywalls, 0);
  });

  testWidgets('an image over 15 MB is refused before any upload starts', (tester) async {
    await setViewport(tester);
    final tempDirectory = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-upload-big-')))!;
    addTearDown(() => tester.runAsync(() => tempDirectory.delete(recursive: true)));
    final image = File('${tempDirectory.path}/big.jpg');
    await tester.runAsync(() => image.writeAsBytes(List<int>.filled(15 * 1024 * 1024 + 1, 0)));
    var uploadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: UploadWallScreen(
          image: image,
          uploadFileForTesting: ({required isThumbnail}) async {
            uploadCalls++;
            return const GitHubContent(downloadUrl: 'u', path: 'p', sha: 's');
          },
        ),
      ),
    );
    for (var i = 0; i < 50 && find.text('Image could not be prepared').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Image could not be prepared'), findsOneWidget);
    expect(find.text('This image is over 15 MB. Choose a smaller one.'), findsOneWidget);
    expect(find.text('Choose another image'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
    expect(uploadCalls, 0);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance ? foregroundLuminance : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance ? backgroundLuminance : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
