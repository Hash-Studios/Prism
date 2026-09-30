import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a loaded small image fills a loosely constrained grid stack', (tester) async {
    const String url = 'https://example.com/small-wall.png';
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 10, 10), ui.Paint()..color = Colors.red);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = (await tester.runAsync(() => picture.toImage(10, 10)))!;
    picture.dispose();
    addTearDown(image.dispose);
    const CachedNetworkImageProvider provider = CachedNetworkImageProvider(url);
    PaintingBinding.instance.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(Future<ImageInfo>.value(ImageInfo(image: image.clone()))),
    );
    addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 400,
            child: Stack(children: [PrismImageTile(url: url)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.getSize(find.byType(RawImage)), const Size(200, 400));
  });

  testWidgets('keeps the image still instead of flying a Hero under reduce motion', (tester) async {
    Widget host(bool reduce) => MaterialApp(
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
