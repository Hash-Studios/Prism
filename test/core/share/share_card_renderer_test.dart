import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

const ShareResult _shared = ShareResult('', ShareResultStatus.success);
const ShareResult _dismissed = ShareResult('', ShareResultStatus.dismissed);

void main() {
  late BuildContext context;

  Future<void> pumpContext(WidgetTester tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
  }

  Future<File> okRender({required String imageUrl, required String link, String? contextLine}) async =>
      File('card.png');
  Future<File> failRender({required String imageUrl, required String link, String? contextLine}) async =>
      throw StateError('no image');

  testWidgets('the card never gets a context line that holds an email address', (tester) async {
    await pumpContext(tester);
    final List<String?> lines = <String?>[];
    Future<File> recordingRender({required String imageUrl, required String link, String? contextLine}) async {
      lines.add(contextLine);
      return File('card.png');
    }

    await tester.runAsync(() async {
      for (final String? line in <String?>['by ana@example.com', 'by Ana Lee', null]) {
        await shareWallpaperCard(
          context,
          imageUrl: 'u',
          link: 'https://x.test/a',
          contextLine: line,
          render: recordingRender,
          sendCard: ({required String text, required File file, required BuildContext context}) async => _shared,
          sendText: ({required String text, required BuildContext context}) async => _shared,
        );
      }
    });

    expect(lines, <String?>[null, 'by Ana Lee', null]);
  });

  testWidgets('shares the card file with the link text when rendering works', (tester) async {
    await pumpContext(tester);
    File? sent;
    String? sentText;

    final ShareCardResult? result = await tester.runAsync(
      () => shareWallpaperCard(
        context,
        imageUrl: 'u',
        link: 'https://x.test/a',
        render: okRender,
        sendCard: ({required String text, required File file, required BuildContext context}) async {
          sent = file;
          sentText = text;
          return _shared;
        },
        sendText: ({required String text, required BuildContext context}) async => fail('text fallback used'),
      ),
    );

    expect(result?.format, ShareFormatValue.card);
    expect(result?.dismissed, isFalse);
    expect(sent?.path, 'card.png');
    expect(sentText, '🔥Check this out ➜ https://x.test/a');
  });

  testWidgets('reports a dismissed card share', (tester) async {
    await pumpContext(tester);
    final ShareCardResult? result = await tester.runAsync(
      () => shareWallpaperCard(
        context,
        imageUrl: 'u',
        link: 'https://x.test/a',
        render: okRender,
        sendCard: ({required String text, required File file, required BuildContext context}) async => _dismissed,
        sendText: ({required String text, required BuildContext context}) async => fail('text fallback used'),
      ),
    );

    expect(result?.format, ShareFormatValue.card);
    expect(result?.dismissed, isTrue);
  });

  testWidgets('reports a dismissed text fallback share', (tester) async {
    await pumpContext(tester);
    final ShareCardResult result = await shareWallpaperCard(
      context,
      imageUrl: 'u',
      link: 'https://x.test/a',
      render: failRender,
      sendCard: ({required String text, required File file, required BuildContext context}) async => fail('card sent'),
      sendText: ({required String text, required BuildContext context}) async => _dismissed,
    );

    expect(result.format, ShareFormatValue.text);
    expect(result.dismissed, isTrue);
  });

  testWidgets('falls back to the text link when rendering fails', (tester) async {
    await pumpContext(tester);
    final List<String> texts = <String>[];

    final ShareCardResult result = await shareWallpaperCard(
      context,
      imageUrl: 'u',
      link: 'https://x.test/a',
      render: failRender,
      sendCard: ({required String text, required File file, required BuildContext context}) async => fail('card sent'),
      sendText: ({required String text, required BuildContext context}) async {
        texts.add(text);
        return _shared;
      },
    );

    expect(result.format, ShareFormatValue.text);
    expect(result.dismissed, isFalse);
    expect(texts.single, '🔥Check this out ➜ https://x.test/a');
  });

  testWidgets('falls back to the text link when sending the card fails', (tester) async {
    await pumpContext(tester);
    final List<String> texts = <String>[];

    final ShareCardResult? result = await tester.runAsync(
      () => shareWallpaperCard(
        context,
        imageUrl: 'u',
        link: 'https://x.test/a',
        render: okRender,
        sendCard: ({required String text, required File file, required BuildContext context}) async =>
            throw StateError('share failed'),
        sendText: ({required String text, required BuildContext context}) async {
          texts.add(text);
          return _shared;
        },
      ),
    );

    expect(result?.format, ShareFormatValue.text);
    expect(result?.dismissed, isFalse);
    expect(texts.single, '🔥Check this out ➜ https://x.test/a');
  });

  testWidgets('deletes the rendered file after sending the card', (tester) async {
    await pumpContext(tester);
    await tester.runAsync(() async {
      final Directory dir = await Directory.systemTemp.createTemp('prism_share_test_');
      final File card = File('${dir.path}/card.png')..writeAsStringSync('image');
      var existedDuringSend = false;

      await shareWallpaperCard(
        context,
        imageUrl: 'u',
        link: 'https://x.test/a',
        render: ({required String imageUrl, required String link, String? contextLine}) async => card,
        sendCard: ({required String text, required File file, required BuildContext context}) async {
          existedDuringSend = await file.exists();
          return _shared;
        },
      );

      expect(existedDuringSend, isTrue);
      expect(await card.exists(), isFalse);
      await dir.delete();
    });
  });

  testWidgets('deletes the rendered file when sending the card fails', (tester) async {
    await pumpContext(tester);
    await tester.runAsync(() async {
      final Directory dir = await Directory.systemTemp.createTemp('prism_share_test_');
      final File card = File('${dir.path}/card.png')..writeAsStringSync('image');

      await shareWallpaperCard(
        context,
        imageUrl: 'u',
        link: 'https://x.test/a',
        render: ({required String imageUrl, required String link, String? contextLine}) async => card,
        sendCard: ({required String text, required File file, required BuildContext context}) async =>
            throw StateError('share failed'),
        sendText: ({required String text, required BuildContext context}) async => _shared,
      );

      expect(await card.exists(), isFalse);
      await dir.delete();
    });
  });

  testWidgets('deletes the rendered file when the context unmounts before sharing', (tester) async {
    await pumpContext(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final Directory dir = await Directory.systemTemp.createTemp('prism_share_test_');
      final File card = File('${dir.path}/card.png')..writeAsStringSync('image');
      var sent = false;
      await shareWallpaperCard(
        context,
        imageUrl: 'u',
        link: 'https://x.test/a',
        render: ({required String imageUrl, required String link, String? contextLine}) async => card,
        sendCard: ({required String text, required File file, required BuildContext context}) async {
          sent = true;
          return _shared;
        },
      );
      expect(sent, isFalse);
      expect(await card.exists(), isFalse);
      await dir.delete();
    });
  });

  testWidgets('unmounts off-screen card widgets after painting', (tester) async {
    var disposed = false;
    RenderRepaintBoundary? boundary;
    await tester.runAsync(() async {
      final ui.Image wall = await createTestImage(width: 54, height: 96);
      final ui.Image logo = await createTestImage(width: 10, height: 10);
      await paintShareCard(
        Builder(
          builder: (BuildContext context) {
            boundary = context.findAncestorRenderObjectOfType<RenderRepaintBoundary>();
            return _DisposeProbe(
              onDispose: () => disposed = true,
              child: ShareCard(wallpaper: wall, logo: logo, link: 'https://prismwalls.com'),
            );
          },
        ),
      );
      wall.dispose();
      logo.dispose();
    });

    expect(disposed, isTrue);
    expect(boundary?.debugDisposed, isTrue);
  });

  testWidgets('decodes panorama within bounds and disposes both resolved images', (tester) async {
    await tester.runAsync(() async {
      final Directory tempDir = await Directory.systemTemp.createTemp('prism_render_test_');
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async => tempDir.path,
      );
      final Uint8List panoramaBytes = await _encodeTestImage(3240, 1080);
      final Uint8List logoBytes = await _encodeTestImage(10, 10);
      final List<ui.Image> decoded = <ui.Image>[];
      final File file = await renderShareCardFile(
        imageUrl: 'unused',
        link: 'https://prismwalls.com',
        wallpaperProvider: MemoryImage(panoramaBytes),
        logoProvider: MemoryImage(logoBytes),
        resolveImage: (ImageProvider provider) async {
          final ui.Image image = await _resolveImage(provider);
          decoded.add(image);
          return image;
        },
      );

      expect((decoded.first.width, decoded.first.height), (1080, 360));
      expect(decoded.every((ui.Image image) => image.debugDisposed), isTrue);
      await file.delete();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await tempDir.delete();
    });
  });

  testWidgets('disposes the wallpaper when resolving the logo fails', (tester) async {
    await tester.runAsync(() async {
      final ui.Image wall = await createTestImage(width: 54, height: 96);
      var resolutions = 0;
      await expectLater(
        renderShareCardFile(
          imageUrl: 'unused',
          link: 'https://prismwalls.com',
          resolveImage: (ImageProvider provider) async {
            resolutions++;
            if (resolutions == 1) return wall;
            throw StateError('logo unavailable');
          },
        ),
        throwsStateError,
      );
      expect(wall.debugDisposed, isTrue);
    });
  });

  testWidgets('removes the image listener after a load timeout', (tester) async {
    final Completer<ImageInfo> image = Completer<ImageInfo>();
    final _PendingImageProvider provider = _PendingImageProvider(image.future);
    final Future<File> render = renderShareCardFile(
      imageUrl: 'unused',
      link: 'https://prismwalls.com',
      wallpaperProvider: provider,
    );
    final Future<void> expectation = expectLater(render, throwsA(isA<TimeoutException>()));

    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    await expectation;
    PaintingBinding.instance.imageCache.clear();
    expect(provider.completer.hasListeners, isFalse);
  });

  testWidgets('paints a real 1080x1920 PNG off-screen', (tester) async {
    await tester.runAsync(() async {
      final ui.Image wall = await createTestImage(width: 54, height: 96);
      final ui.Image logo = await createTestImage(width: 10, height: 10);
      final ByteData? bytes = await paintShareCard(
        ShareCard(wallpaper: wall, logo: logo, link: 'https://prismwalls.com', contextLine: 'by A'),
      );
      expect(bytes, isNotNull);
      final ui.Codec codec = await ui.instantiateImageCodec(bytes!.buffer.asUint8List());
      final ui.Image decoded = (await codec.getNextFrame()).image;
      expect((decoded.width, decoded.height), (1080, 1920));
      decoded.dispose();
      codec.dispose();
      wall.dispose();
      logo.dispose();
    });
  });
}

class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe({required this.onDispose, required this.child});

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

class _PendingImageProvider extends ImageProvider<int> {
  _PendingImageProvider(Future<ImageInfo> image) : completer = OneFrameImageStreamCompleter(image);

  final ImageStreamCompleter completer;

  @override
  Future<int> obtainKey(ImageConfiguration configuration) async => identityHashCode(this);

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    int key,
    ImageErrorListener handleError,
  ) {
    stream.setCompleter(completer);
  }

  @override
  ImageStreamCompleter loadImage(int key, ImageDecoderCallback decode) => completer;
}

Future<Uint8List> _encodeTestImage(int width, int height) async {
  final ui.Image image = await createTestImage(width: width, height: height);
  try {
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _resolveImage(ImageProvider provider) {
  final Completer<ui.Image> resolved = Completer<ui.Image>();
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, _) {
      stream.removeListener(listener);
      resolved.complete(info.image);
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      resolved.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return resolved.future;
}
