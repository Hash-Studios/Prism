import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/widgets/wrapped_card_view.dart';
import 'package:Prism/features/wrapped/views/wrapped_copy.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

const String wrappedShareLink = 'https://prismwalls.com/wrapped';

/// The walls a card draws: four for the summary collage, else its hero.
List<String> wrappedCardImages(WrappedCard card) => card.kind == WrappedCardKind.summary && card.thumbs.length >= 4
    ? card.thumbs.take(4).toList()
    : <String>[card.heroUrl];

/// Opens the share sheet with [card] as a 9:16 story image. The image holds the card's own copy, its walls, the logo
/// and the link, nothing else about the user.
Future<void> shareWrappedCard(
  BuildContext context, {
  required WrappedCard card,
  required WrappedCopy copy,
  required Color accent,
  required String ownerUserId,
  Stream<String>? ownerChanges,
  ShareSheetServices? services,
}) => showShareSheet(
  context,
  ShareCardContent(imageUrl: card.heroUrl, link: wrappedShareLink, brandName: 'Prism', contentId: card.id),
  'wrapped',
  formats: const <ShareCardFormat>[ShareCardFormat.story],
  ownerUserId: ownerUserId,
  ownerChanges: ownerChanges,
  services:
      services ?? ShareSheetServices(render: (_, _) => renderWrappedShareFile(copy, wrappedCardImages(card), accent)),
  onTargetDone: (target) => analytics.track(WrappedCardSharedEvent(cardId: card.id, target: target)),
);

/// Renders the story image to a temp PNG. [resolveImage] and [loadImage] are seams for tests.
Future<File> renderWrappedShareFile(
  WrappedCopy copy,
  List<String> urls,
  Color accent, {
  ShareCardImageResolver resolveImage = resolveShareCardImage,
  Future<ImageProvider> Function(String url)? loadImage,
}) async {
  const Size size = Size(1080, 1920);
  final List<ui.Image> images = <ui.Image>[];
  ui.Image? logo;
  try {
    for (final String url in urls) {
      final ImageProvider provider = await (loadImage ?? _localImage)(url);
      images.add(
        await resolveImage(
          ResizeImage(provider, width: size.width.toInt(), height: size.height.toInt(), policy: ResizeImagePolicy.fit),
        ),
      );
    }
    logo = await resolveImage(const AssetImage(ShareCardStyle.logoAsset));
    Widget tile(ui.Image image) => RawImage(image: image, fit: BoxFit.cover);
    final ByteData? bytes = await paintShareCard(
      SizedBox.fromSize(
        size: size,
        child: WrappedCardView(
          copy: copy,
          accent: accent,
          scale: 3,
          background: WrappedCollage(tiles: images.map(tile).toList(), gap: 6),
          footer: Row(
            children: <Widget>[
              RawImage(image: logo, width: 72, height: 72),
              const SizedBox(width: 24),
              const Text(WrappedCardStyle.link, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
    if (bytes == null) throw StateError('wrapped card encode failed');
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/prism_wrapped_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  } finally {
    for (final ui.Image image in images) {
      image.dispose();
    }
    logo?.dispose();
  }
}

Future<ImageProvider> _localImage(String url) async => FileImage(await WallpaperService.resolveToLocalFile(url));
