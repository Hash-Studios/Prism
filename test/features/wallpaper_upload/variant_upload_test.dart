import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/wall_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/wait_for_real_io.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

const VariantSeed _seed = VariantSeed(
  wallDocId: 'wall_original',
  thumbnailUrl: 'https://example.com/original.jpg',
  title: 'Dusk Sea',
);

Future<void> _pumpTile(WidgetTester tester, Map<String, dynamic> payload) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: WallTile(FirestoreDocument('variant_tile', payload), rejected: false)),
      ),
    ),
  );
  tester.takeException();
}

void main() {
  const Map<String, dynamic> base = <String, dynamic>{
    'size': '2 MB',
    'resolution': '1440x3200',
    'wallpaper_url': 'https://example.com/w.jpg',
  };

  group('draft store', () {
    late Directory root;
    late Directory recordsDirectory;
    late Directory filesDirectory;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('prism-variant-draft-test');
      recordsDirectory = Directory('${root.path}/records');
      filesDirectory = Directory('${root.path}/draft-files');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('round-trips the variant link after the store is reopened', () async {
      final File original = File('${root.path}/selected.png')..writeAsBytesSync(<int>[1, 2, 3]);
      final UploadDraftStore firstRun = UploadDraftStore(
        store: DurableJsonStore('variant_draft_test', directory: recordsDirectory),
        directory: filesDirectory,
      );
      await firstRun.save(
        owner: 'account',
        draftId: 'image',
        selectedFile: original,
        metadata: const SubmissionMetadata(
          variantOf: 'wall_original',
          variantThumb: 'https://example.com/original.jpg',
          variantTitle: 'Dusk Sea',
        ),
      );
      final UploadDraftStore restarted = UploadDraftStore(
        store: DurableJsonStore('variant_draft_test', directory: recordsDirectory),
        directory: filesDirectory,
      );

      final UploadDraft restored = (await restarted.read(owner: 'account', draftId: 'image'))!;

      expect(restored.metadata.variantOf, 'wall_original');
      expect(restored.metadata.variantThumb, 'https://example.com/original.jpg');
      expect(restored.metadata.variantTitle, 'Dusk Sea');
      expect(restored.metadata.variantRemoved, isFalse);
    });
  });

  group('upload screen', () {
    late _MockCacheManager imageCache;

    setUp(() {
      AnalyticsRuntime.reset();
      imageCache = _MockCacheManager();
      when(
        () => imageCache.getFileStream(
          any(),
          withProgress: any(named: 'withProgress'),
          headers: any(named: 'headers'),
          key: any(named: 'key'),
        ),
      ).thenAnswer((_) => const Stream<FileResponse>.empty());
      when(() => imageCache.getFileFromCache(any())).thenAnswer((_) async => null);
      PrismImageCache.testOverride = imageCache;
    });
    tearDown(() {
      PrismImageCache.testOverride = null;
      AnalyticsRuntime.reset();
    });

    testWidgets('variant chip shows the wall title and its remove button hides it', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      tester.view.physicalSize = const Size(360, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final File image = await _makeImage(tester);
      final Directory root = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-variant-upload-')))!;
      addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
      final UploadDraftStore drafts = UploadDraftStore(
        store: DurableJsonStore('variant_upload_screen', directory: Directory('${root.path}/records')),
        directory: Directory('${root.path}/files'),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UploadWallScreen(
            image: image,
            variantSeed: _seed,
            prepareImageForTesting: () async {},
            draftStoreForTesting: drafts,
            deleteFileForTesting: ({required path, required sha}) async {},
          ),
        ),
      );
      await _pumpImagePreparation(tester);

      expect(find.text('Colour variant of Dusk Sea'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Upload as a new wallpaper instead'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Upload as a new wallpaper instead'));
      await tester.pump();

      expect(find.text('Colour variant of Dusk Sea'), findsNothing);
      expect(find.byTooltip('Upload as a new wallpaper instead'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('submission metadata', () {
    test('copyWith keeps the variant fields and variantSeed reads them back', () {
      const SubmissionMetadata metadata = SubmissionMetadata(
        variantOf: 'wall_original',
        variantThumb: 'https://example.com/original.jpg',
        variantTitle: 'Dusk Sea',
      );

      final SubmissionMetadata edited = metadata.copyWith(title: 'Edited');

      expect(edited.variantOf, 'wall_original');
      expect(edited.variantThumb, 'https://example.com/original.jpg');
      expect(edited.variantTitle, 'Dusk Sea');
      expect(edited.variantRemoved, isFalse);
      expect(edited.variantSeed?.wallDocId, 'wall_original');
      expect(edited.variantSeed?.title, 'Dusk Sea');
    });

    test('a removed variant has no variantSeed', () {
      const SubmissionMetadata metadata = SubmissionMetadata(variantOf: 'wall_original');

      final SubmissionMetadata removed = metadata.copyWith(
        variantOf: '',
        variantThumb: '',
        variantTitle: '',
        variantRemoved: true,
      );

      expect(removed.variantSeed, isNull);
      expect(removed.variantRemoved, isTrue);
    });
  });

  group('wall tile variant status', () {
    testWidgets('shows the dropped reason for a group that is full', (tester) async {
      await _pumpTile(tester, <String, dynamic>{...base, 'variantOf': 'wall_original', 'variantLink': 'group_full'});

      expect(find.text('Not added as a colour variant'), findsOneWidget);
      expect(find.text('The set already has 5 colours.'), findsOneWidget);
    });

    testWidgets('shows the pending line for a variant that is waiting for review', (tester) async {
      await _pumpTile(tester, <String, dynamic>{...base, 'variantOf': 'wall_original'});

      expect(find.text('Colour variant. It joins the set after review.'), findsOneWidget);
    });

    testWidgets('shows no variant text for a plain upload', (tester) async {
      await _pumpTile(tester, base);

      expect(find.text('Colour variant. It joins the set after review.'), findsNothing);
      expect(find.text('Not added as a colour variant'), findsNothing);
      expect(find.text('In a set of colour variants'), findsNothing);
    });
  });
}

Future<File> _makeImage(WidgetTester tester) async {
  final Directory directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-variant-image-')))!;
  addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
  final File image = File('${directory.path}/pixel.png');
  await tester.runAsync(
    () => image.writeAsBytes(
      base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC'),
    ),
  );
  return image;
}

Future<void> _pumpImagePreparation(WidgetTester tester) async {
  await waitForRealIo(
    tester,
    () =>
        find.text('Ready to submit').evaluate().isNotEmpty ||
        find.text('Image could not be prepared').evaluate().isNotEmpty,
    reason: 'upload image preparation',
    pumpDuration: const Duration(milliseconds: 16),
  );
}
