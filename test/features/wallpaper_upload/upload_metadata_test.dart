import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _BatchRouter extends AppRouter {
  _BatchRouter(this.uploadRoute);

  final UploadWallRoute Function() uploadRoute;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo(
        'BatchHost',
        builder: (_) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.router.push<Object?>(uploadRoute()),
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    ),
    AutoRoute(path: '/upload-wall', page: UploadWallRoute.page),
    AutoRoute(
      path: '/edit-wall',
      page: PageInfo(EditWallRoute.name, builder: (_) => const Scaffold(body: Text('edit-stub'))),
    ),
    AutoRoute(
      path: '/review',
      page: PageInfo(ReviewRoute.name, builder: (_) => const Scaffold(body: Text('review-stub'))),
    ),
  ];
}

const GitHubContent _wall = GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'w');
const GitHubContent _thumb = GitHubContent(downloadUrl: 'https://example.test/t.png', path: 'thumb_p.png', sha: 't');

Future<GitHubContent> _upload({required bool isThumbnail}) async => isThumbnail ? _thumb : _wall;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late FakeAppAnalytics recorder;
  late List<String> toastMessages;

  setUp(() {
    recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    toastMessages = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  Future<File> makeImage(WidgetTester tester) async {
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-upload-meta-')))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final image = File('${dir.path}/pixel.png');
    await tester.runAsync(
      () => image.writeAsBytes(
        base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC'),
      ),
    );
    return image;
  }

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpReady(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    File image, {
    Size? size,
    UploadBatch? batch,
    Future<GitHubContent> Function({required bool isThumbnail})? upload,
    Future<wall_store.WallSubmissionResult> Function({required String id, required SubmissionMetadata metadata})? save,
  }) async {
    final router = _BatchRouter(
      () => UploadWallRoute(
        image: image,
        batch: batch,
        imageSizeForTesting: size,
        prepareImageForTesting: () async {},
        uploadFileForTesting: upload ?? _upload,
        deleteFileForTesting: ({required path, required sha}) async {},
        createRecordWithMetadataForTesting:
            save ?? ({required id, required metadata}) async => wall_store.WallSubmissionResult.submitted,
      ),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await router.navigatePath('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open uploader'));
    await pumpReady(tester);
  }

  testWidgets('a new wall gets a ten character id and default details when the creator adds none', (tester) async {
    setViewport(tester);
    final image = await makeImage(tester);
    String? savedId;
    SubmissionMetadata? savedMetadata;
    await pumpScreen(
      tester,
      image,
      save: ({required id, required metadata}) async {
        savedId = id;
        savedMetadata = metadata;
        return wall_store.WallSubmissionResult.submitted;
      },
    );

    expect(find.text('Details (optional)'), findsOneWidget);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(savedId, hasLength(10));
    expect(savedId, matches(RegExp(r'^[A-Z0-9]+$')));
    expect(savedMetadata!.title, '');
    expect(savedMetadata!.category, 'General');
    expect(savedMetadata!.tags, isEmpty);
    final event = recorder.events.whereType<UploadMetadataSubmittedEvent>().single;
    expect((event.hasTitle, event.tagCount, event.category), (false, 0, 'General'));
  });

  testWidgets('the title, tags and category the creator picks reach the record and the event', (tester) async {
    setViewport(tester);
    final image = await makeImage(tester);
    SubmissionMetadata? savedMetadata;
    await pumpScreen(
      tester,
      image,
      save: ({required id, required metadata}) async {
        savedMetadata = metadata;
        return wall_store.WallSubmissionResult.submitted;
      },
    );

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Calm dunes');
    await tester.enterText(find.widgetWithText(TextField, 'Tags'), '#Sand, Desert,');
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Nature'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Nature'));
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'sand'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'desert'), findsOneWidget);

    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(savedMetadata!.title, 'Calm dunes');
    expect(savedMetadata!.tags, <String>['sand', 'desert']);
    expect(savedMetadata!.category, 'Nature');
    final event = recorder.events.whereType<UploadMetadataSubmittedEvent>().single;
    expect((event.hasTitle, event.tagCount, event.category), (true, 2, 'Nature'));
  });

  testWidgets('a tag can be removed and only eight tags are kept', (tester) async {
    setViewport(tester);
    final image = await makeImage(tester);
    SubmissionMetadata? savedMetadata;
    await pumpScreen(
      tester,
      image,
      save: ({required id, required metadata}) async {
        savedMetadata = metadata;
        return wall_store.WallSubmissionResult.submitted;
      },
    );

    await tester.enterText(find.widgetWithText(TextField, 'Tags'), 'a1,b2,c3,d4,e5,f6,g7,h8,i9,');
    await tester.pump();
    expect(find.byType(InputChip), findsNWidgets(maxSubmissionTags));
    await tester.ensureVisible(find.byTooltip('Remove tag a1'));
    await tester.tap(find.byTooltip('Remove tag a1'));
    await tester.pump();
    expect(find.byType(InputChip), findsNWidgets(maxSubmissionTags - 1));

    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(savedMetadata!.tags, hasLength(7));
    expect(savedMetadata!.tags, isNot(contains('a1')));
  });

  group('quality warnings', () {
    testWidgets('a sharp portrait image shows none', (tester) async {
      setViewport(tester);
      await pumpScreen(tester, await makeImage(tester), size: const Size(1080, 2400));

      expect(find.textContaining('soft on a phone'), findsNothing);
      expect(find.textContaining('This image is wide'), findsNothing);
    });

    testWidgets('a small image warns about resolution and still submits', (tester) async {
      setViewport(tester);
      var saved = false;
      await pumpScreen(
        tester,
        await makeImage(tester),
        size: const Size(720, 1600),
        save: ({required id, required metadata}) async {
          saved = true;
          return wall_store.WallSubmissionResult.submitted;
        },
      );

      expect(find.textContaining('720x1600'), findsWidgets);
      expect(find.textContaining('soft on a phone'), findsOneWidget);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
    });

    testWidgets('a landscape image warns', (tester) async {
      setViewport(tester);
      await pumpScreen(tester, await makeImage(tester), size: const Size(3000, 2000));

      expect(find.textContaining('This image is wide'), findsOneWidget);
      expect(find.textContaining('soft on a phone'), findsNothing);
    });
  });

  group('analytics', () {
    testWidgets('tracks the upload stages up to submitted', (tester) async {
      setViewport(tester);
      await pumpScreen(tester, await makeImage(tester));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(recorder.events.whereType<UploadStageEvent>().map((e) => e.stage), <String>[
        'ready',
        'uploading',
        'saving',
        'submitted',
      ]);
      expect(recorder.events.whereType<UploadFailedEvent>(), isEmpty);
    });

    testWidgets('tracks why an upload failed', (tester) async {
      setViewport(tester);
      await pumpScreen(
        tester,
        await makeImage(tester),
        upload: ({required isThumbnail}) async => throw StateError('offline'),
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(recorder.events.whereType<UploadFailedEvent>().map((e) => e.reason), <String>['upload']);
    });

    testWidgets('tracks a save that could not be confirmed', (tester) async {
      setViewport(tester);
      await pumpScreen(
        tester,
        await makeImage(tester),
        save: ({required id, required metadata}) async => throw StateError('lost'),
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(recorder.events.whereType<UploadFailedEvent>().map((e) => e.reason), <String>['submission']);
    });
  });

  group('batch', () {
    Future<UploadBatch> pumpRoutedBatch(WidgetTester tester, {int count = 2}) async {
      setViewport(tester);
      final images = <File>[for (var i = 0; i < count; i++) await makeImage(tester)];
      final batch = UploadBatch(images);
      final router = _BatchRouter(
        () => UploadWallRoute(
          image: batch.current,
          batch: batch,
          prepareImageForTesting: () async {},
          uploadFileForTesting: _upload,
          deleteFileForTesting: ({required path, required sha}) async {},
          createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
        ),
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
      await router.navigatePath('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open uploader'));
      await pumpReady(tester);
      return batch;
    }

    testWidgets('shows the step and moves to the next image after a submit', (tester) async {
      final batch = await pumpRoutedBatch(tester);

      expect(find.text('Wallpaper 1 of 2'), findsOneWidget);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(find.text('edit-stub'), findsOneWidget);
      expect(batch.position, 2);
      expect(batch.outcomes, <UploadItemOutcome>[UploadItemOutcome.submitted, UploadItemOutcome.pending]);
    });

    testWidgets('Skip records the image as skipped and moves on', (tester) async {
      final batch = await pumpRoutedBatch(tester);

      await tester.tap(find.text('Skip this wallpaper'));
      await tester.pumpAndSettle();

      expect(find.text('edit-stub'), findsOneWidget);
      expect(batch.outcomes.first, UploadItemOutcome.skipped);
      expect(batch.position, 2);
    });

    testWidgets('a single image shows no step and no Skip button', (tester) async {
      setViewport(tester);
      await pumpScreen(tester, await makeImage(tester));

      expect(find.textContaining('Wallpaper 1 of'), findsNothing);
      expect(find.text('Skip this wallpaper'), findsNothing);
    });

    testWidgets('submitting the last image shows the summary and opens review status', (tester) async {
      setViewport(tester);
      final images = <File>[await makeImage(tester), await makeImage(tester)];
      final batch = UploadBatch(images)
        ..finishCurrent(UploadItemOutcome.submitted)
        ..advance();
      final router = _BatchRouter(
        () => UploadWallRoute(
          image: batch.current,
          batch: batch,
          prepareImageForTesting: () async {},
          uploadFileForTesting: _upload,
          deleteFileForTesting: ({required path, required sha}) async {},
          createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
        ),
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
      await router.navigatePath('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open uploader'));
      await pumpReady(tester);

      expect(find.text('Wallpaper 2 of 2'), findsOneWidget);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(find.text('review-stub'), findsOneWidget);
      expect(toastMessages, contains('2 of 2 wallpapers submitted'));
    });
  });
}
