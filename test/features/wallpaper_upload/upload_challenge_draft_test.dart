import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_submission_result.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/wait_for_real_io.dart';

class _DraftStoreFixture {
  const _DraftStoreFixture(this.root);

  final Directory root;

  UploadDraftStore open() => UploadDraftStore(
    store: DurableJsonStore('upload_screen_test', directory: Directory('${root.path}/records')),
    directory: Directory('${root.path}/files'),
  );
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

  testWidgets('removing challenge survives keep draft and reopening with route prefill', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final fixture = await makeDraftStore(tester);
    UploadDraftStore drafts = fixture.open();
    SubmissionMetadata? submitted;
    Widget uploader() => UploadWallScreen(
      image: image,
      prepareImageForTesting: () async {},
      draftStoreForTesting: drafts,
      deleteFileForTesting: ({required path, required sha}) async {},
      challengeSeed: const ChallengeSeed(id: '2026-10-26', theme: 'Quiet oceans'),
      uploadFileForTesting: ({required isThumbnail}) async =>
          const GitHubContent(downloadUrl: 'https://example.com/image.png', path: 'image.png', sha: 'sha'),
      createRecordWithMetadataForTesting: ({required id, required metadata}) async {
        submitted = metadata;
        return WallSubmissionResult.quotaExceeded;
      },
    );
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
    await pumpImagePreparation(tester);
    await tester.scrollUntilVisible(find.byTooltip('Remove challenge'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Remove challenge'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep draft'));
    await waitForRealIo(
      tester,
      () => find.text('Upload wallpaper').evaluate().isEmpty,
      reason: 'save removed challenge',
      pumpDuration: const Duration(milliseconds: 16),
    );
    drafts = fixture.open();
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    expect(find.byTooltip('Remove challenge'), findsNothing);
    await tester.ensureVisible(find.text('Upload'));
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(submitted?.challengeId, '');
    expect(submitted?.title, 'Quiet oceans');
    await tester.pumpWidget(const SizedBox());
    await waitForStoreOperation(
      tester,
      drafts.latestForOwner(UploadDraftStore.guestOwner),
      reason: 'finish draft writes',
    );
  });
}
