import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

typedef ShareCardRender = Future<File> Function({required String imageUrl, required String link, String? contextLine});
typedef ShareCardSend =
    Future<void> Function({required String text, required File file, required BuildContext context});
typedef ShareTextSend = Future<void> Function({required String text, required BuildContext context});

Future<void> _sendCard({required String text, required File file, required BuildContext context}) =>
    ShareService.shareFile(file: file, text: text, context: context);

Future<void> _sendText({required String text, required BuildContext context}) =>
    ShareService.shareText(text: text, context: context);

/// Shares [link] with a branded image card. Falls back to plain text when the card cannot be made or sent, so
/// sharing never blocks. Returns the format that was shared.
Future<ShareFormatValue> shareWallpaperCard(
  BuildContext context, {
  required String imageUrl,
  required String link,
  String? contextLine,
  ShareCardRender render = renderShareCardFile,
  ShareCardSend sendCard = _sendCard,
  ShareTextSend sendText = _sendText,
}) async {
  final String text = '🔥Check this out ➜ $link';
  try {
    final File file = await render(imageUrl: imageUrl, link: link, contextLine: contextLine);
    if (!context.mounted) return ShareFormatValue.text;
    await sendCard(text: text, file: file, context: context);
    return ShareFormatValue.card;
  } catch (error, stackTrace) {
    logger.w('Share card failed; sharing text', error: error, stackTrace: stackTrace);
  }
  if (!context.mounted) return ShareFormatValue.text;
  await sendText(text: text, context: context);
  return ShareFormatValue.text;
}

/// Renders the card off-screen and writes it to the temp dir as a PNG.
Future<File> renderShareCardFile({required String imageUrl, required String link, String? contextLine}) async {
  final List<ui.Image> images = await Future.wait(<Future<ui.Image>>[
    // Height 1920 decodes at card size (no 4K decode) and reads the image cache, so no second download.
    _resolve(ResizeImage(CachedNetworkImageProvider(imageUrl), height: 1920)),
    _resolve(const AssetImage(ShareCardStyle.logoAsset)),
  ]);
  final ByteData? bytes = await paintShareCard(
    ShareCard(wallpaper: images[0], logo: images[1], link: link, contextLine: contextLine),
  );
  if (bytes == null) throw StateError('share card encode failed');
  final Directory dir = await getTemporaryDirectory();
  return File(
    '${dir.path}/prism_share_${DateTime.now().millisecondsSinceEpoch}.png',
  ).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
}

Future<ui.Image> _resolve(ImageProvider provider) {
  final Completer<ui.Image> done = Completer<ui.Image>();
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, _) {
      if (!done.isCompleted) done.complete(info.image);
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!done.isCompleted) done.completeError(error, stackTrace);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return done.future.timeout(const Duration(seconds: 12));
}

/// Lays out and paints [card] in its own render tree, so it never needs to be on screen.
Future<ByteData?> paintShareCard(Widget card) async {
  final RenderRepaintBoundary boundary = RenderRepaintBoundary();
  final PipelineOwner pipelineOwner = PipelineOwner();
  final RenderView renderView = RenderView(
    view: WidgetsBinding.instance.platformDispatcher.views.first,
    configuration: ViewConfiguration(logicalConstraints: BoxConstraints.tight(ShareCardStyle.size)),
    child: RenderPositionedBox(child: boundary),
  );
  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();
  final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());
  final RenderObjectToWidgetElement<RenderBox> element = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: Directionality(textDirection: TextDirection.ltr, child: card),
  ).attachToRenderTree(buildOwner);
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
}
