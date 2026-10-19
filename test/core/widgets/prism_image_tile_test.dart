import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _PendingOfflineAssetStore extends OfflineAssetStore {
  _PendingOfflineAssetStore(this.retainedSource, this.lookupResult) : super(directory: Directory.systemTemp);

  final String retainedSource;
  final Future<File?> lookupResult;

  @override
  Future<File?> lookup(String source) => source == retainedSource ? lookupResult : Future<File?>.value();
}

bool _isRetainedFileImage(Widget widget) {
  if (widget is! Image) return false;
  final ImageProvider<Object> provider = widget.image;
  return provider is FileImage || (provider is ResizeImage && provider.imageProvider is FileImage);
}

Future<void> _pumpUntilRetainedImage(WidgetTester tester) async {
  final Stopwatch timeout = Stopwatch()..start();
  final Finder retainedImage = find.byWidgetPredicate(_isRetainedFileImage);
  while (retainedImage.evaluate().isEmpty && timeout.elapsed < const Duration(seconds: 2)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)).timeout(const Duration(seconds: 2)),
    );
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  late Directory directory;
  late _MockCacheManager cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prism-image-tile-test-');
    cache = _MockCacheManager();
    PrismImageCache.testOverride = cache;
    OfflineAssetStore.testOverride = OfflineAssetStore(directory: directory, cacheManager: cache);
  });

  tearDown(() async {
    PrismImageCache.testOverride = null;
    OfflineAssetStore.testOverride = null;
    await directory.delete(recursive: true);
  });

  testWidgets('shows the network image while lookup is pending, then the retained original at tile size', (
    tester,
  ) async {
    const String thumbnail = 'https://example.com/thumb.jpg';
    const String original = 'https://example.com/original.jpg';
    final File retainedImage = File('${directory.path}/retained.gif')
      ..writeAsBytesSync(base64Decode('R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs='));
    final Completer<File?> lookup = Completer<File?>();
    final StreamController<FileResponse> networkResponse = StreamController<FileResponse>.broadcast();
    addTearDown(networkResponse.close);
    OfflineAssetStore.testOverride = _PendingOfflineAssetStore(original, lookup.future);
    when(() => cache.getFileStream(thumbnail, withProgress: true)).thenAnswer((_) => networkResponse.stream);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 160,
            height: 240,
            child: PrismImageTile(url: thumbnail, fallbackUrl: original, memCacheHeight: 180),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    verify(() => cache.getFileStream(thumbnail, withProgress: true)).called(1);

    lookup.complete(retainedImage);
    await _pumpUntilRetainedImage(tester);

    final Image image = tester.widget<Image>(find.byWidgetPredicate(_isRetainedFileImage));
    final ResizeImage resizedImage = image.image as ResizeImage;
    expect((resizedImage.imageProvider as FileImage).file.path, retainedImage.path);
    expect(resizedImage.height, 180);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('renders a local file URL directly', (tester) async {
    final String localPath = File('assets/images/wallpaper.jpg').absolute.path;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(width: 160, height: 240, child: PrismImageTile(url: localPath)),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final ImageProvider<Object> provider = tester.widget<Image>(find.byType(Image)).image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).imageProvider, isA<FileImage>());
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('a loaded small image fills a loosely constrained grid stack', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    const String url = 'https://example.com/small-wall.png';
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 10, 10), ui.Paint()..color = Colors.red);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = (await tester.runAsync(() => picture.toImage(10, 10)))!;
    picture.dispose();
    addTearDown(image.dispose);
    const CachedNetworkImageProvider provider = CachedNetworkImageProvider(url);
    const int decodeHeight = 400;
    const ResizeImage resizedProvider = ResizeImage(provider, height: decodeHeight);
    final Object resizedKey = await resizedProvider.obtainKey(ImageConfiguration.empty);
    final Completer<ImageInfo> imageInfo = Completer<ImageInfo>();
    PaintingBinding.instance.imageCache.putIfAbsent(resizedKey, () => OneFrameImageStreamCompleter(imageInfo.future));
    addTearDown(() => PaintingBinding.instance.imageCache.evict(resizedKey));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Center(
          child: SizedBox(
            width: 200,
            height: 400,
            child: Stack(children: [PrismImageTile(url: url)]),
          ),
        ),
      ),
    );
    imageInfo.complete(ImageInfo(image: image.clone()));
    await tester.pumpAndSettle();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.getSize(find.byType(RawImage)), const Size(200, 400));
  });

  testWidgets('keeps the image still instead of flying a Hero under reduce motion', (tester) async {
    Widget host(bool reduce) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: const PrismImageTile(url: '', heroTag: 'wall'),
      ),
    );
    await tester.pumpWidget(host(false));
    expect(find.byType(Hero), findsOneWidget);
    await tester.pumpWidget(host(true));
    expect(find.byType(Hero), findsNothing);
    expect(find.byType(PrismImageTile), findsOneWidget);
  });
}
