import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const ShareCardContent _content = ShareCardContent(
  imageUrl: 'unused',
  link: 'https://prismwalls.com',
  brandName: 'Prism',
);

void main() {
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
        ShareCardFormat.story,
        _content,
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

  testWidgets('renders the post format as a 1080x1350 PNG named after the format', (tester) async {
    await tester.runAsync(() async {
      final Directory tempDir = await Directory.systemTemp.createTemp('prism_render_test_');
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async => tempDir.path,
      );
      final Uint8List wallBytes = await _encodeTestImage(54, 96);
      final Uint8List logoBytes = await _encodeTestImage(10, 10);
      final File file = await renderShareCardFile(
        ShareCardFormat.post,
        _content,
        wallpaperProvider: MemoryImage(wallBytes),
        logoProvider: MemoryImage(logoBytes),
      );

      expect(file.uri.pathSegments.last, startsWith('prism_share_post_'));
      final ui.Codec codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final ui.Image decoded = (await codec.getNextFrame()).image;
      expect((decoded.width, decoded.height), (1080, 1350));
      decoded.dispose();
      codec.dispose();
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
          ShareCardFormat.story,
          _content,
          wallpaperProvider: const AssetImage('provided-wallpaper'),
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
    final Future<File> render = renderShareCardFile(ShareCardFormat.story, _content, wallpaperProvider: provider);
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
        ShareCard(
          wallpaper: wall,
          logo: logo,
          content: const ShareCardContent(
            imageUrl: '',
            link: 'https://prismwalls.com',
            brandName: 'Prism',
            creatorLine: 'by A',
          ),
        ),
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
              child: ShareCard(wallpaper: wall, logo: logo, content: _content),
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
