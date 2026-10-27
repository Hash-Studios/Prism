import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

typedef ShareCardRender = Future<File> Function(ShareCardFormat format, ShareCardContent content);
typedef ShareCardImageResolver = Future<ui.Image> Function(ImageProvider provider);

/// Renders [format] off-screen and writes it to the temp dir as a PNG.
Future<File> renderShareCardFile(
  ShareCardFormat format,
  ShareCardContent content, {
  ImageProvider? wallpaperProvider,
  ImageProvider? logoProvider,
  ShareCardImageResolver resolveImage = _resolve,
}) async {
  ui.Image? wallpaper;
  ui.Image? logo;
  try {
    // Fit within card bounds at decode time while preserving the source aspect ratio.
    final ImageProvider provider;
    if (wallpaperProvider != null) {
      provider = wallpaperProvider;
    } else {
      final File source = await WallpaperService.resolveToLocalFile(content.imageUrl);
      provider = FileImage(source);
    }
    wallpaper = await resolveImage(
      ResizeImage(
        provider,
        width: format.size.width.toInt(),
        height: format.size.height.toInt(),
        policy: ResizeImagePolicy.fit,
      ),
    );
    logo = await resolveImage(logoProvider ?? const AssetImage(ShareCardStyle.logoAsset));
    final ByteData? bytes = await paintShareCard(
      ShareCard(wallpaper: wallpaper, logo: logo, content: content, format: format),
      size: format.size,
    );
    if (bytes == null) throw StateError('share card encode failed');
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/prism_share_${format.name}_${DateTime.now().microsecondsSinceEpoch}.png');
    try {
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file;
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
      } catch (error, stackTrace) {
        logger.w('Could not delete incomplete share card', error: error, stackTrace: stackTrace);
      }
      rethrow;
    }
  } finally {
    wallpaper?.dispose();
    logo?.dispose();
  }
}

Future<ui.Image> _resolve(ImageProvider provider) {
  final Completer<ui.Image> done = Completer<ui.Image>();
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);
  late final Timer timeout;
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) {
        timeout.cancel();
        done.complete(info.image);
      } else {
        info.dispose();
      }
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!done.isCompleted) {
        timeout.cancel();
        done.completeError(error, stackTrace);
      }
    },
  );
  timeout = Timer(const Duration(seconds: 12), () {
    stream.removeListener(listener);
    if (!done.isCompleted) done.completeError(TimeoutException('Image load timed out'));
  });
  stream.addListener(listener);
  return done.future;
}

class _ShareCardAdapter extends RenderObjectToWidgetAdapter<RenderBox> {
  _ShareCardAdapter({required super.container, super.child});

  @override
  _ShareCardElement createElement() => _ShareCardElement(this);
}

class _ShareCardElement extends RenderObjectToWidgetElement<RenderBox> {
  _ShareCardElement(super.widget);

  @override
  void deactivate() => super.deactivate();

  @override
  void unmount() => super.unmount();

  void disposeRoot() {
    deactivate();
    unmount();
  }
}

/// Lays out and paints [card] in its own render tree, so it never needs to be on screen.
Future<ByteData?> paintShareCard(Widget card, {Size size = const Size(1080, 1920)}) async {
  final RenderRepaintBoundary boundary = RenderRepaintBoundary();
  final PipelineOwner pipelineOwner = PipelineOwner();
  final RenderPositionedBox positionedBox = RenderPositionedBox(child: boundary);
  final RenderView renderView = RenderView(
    view: WidgetsBinding.instance.platformDispatcher.views.first,
    configuration: ViewConfiguration(logicalConstraints: BoxConstraints.tight(size)),
    child: positionedBox,
  );
  pipelineOwner.rootNode = renderView;
  final FocusManager focusManager = FocusManager();
  final BuildOwner buildOwner = BuildOwner(focusManager: focusManager);
  _ShareCardElement? element;
  try {
    renderView.prepareInitialFrame();
    element =
        _ShareCardAdapter(
              container: boundary,
              child: Directionality(textDirection: TextDirection.ltr, child: card),
            ).attachToRenderTree(buildOwner)
            as _ShareCardElement;
    buildOwner.buildScope(element);
    buildOwner.finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final ui.Image image = await boundary.toImage();
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  } finally {
    if (element != null) {
      element.update(_ShareCardAdapter(container: boundary));
      buildOwner.buildScope(element);
      buildOwner.finalizeTree();
    }
    pipelineOwner.rootNode = null;
    if (element != null) {
      element.disposeRoot();
    } else {
      boundary.dispose();
    }
    positionedBox.dispose();
    renderView.dispose();
    pipelineOwner.dispose();
    focusManager.dispose();
  }
}
