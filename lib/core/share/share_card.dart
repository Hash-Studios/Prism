import 'dart:ui' as ui;

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:flutter/widgets.dart';

/// The three images the share sheet can send. Each is a fixed pixel size so it looks the same everywhere it lands.
enum ShareCardFormat {
  story(Size(1080, 1920), ShareFormatValue.story),
  post(Size(1080, 1350), ShareFormatValue.post),
  clean(Size(1080, 1920), ShareFormatValue.clean);

  const ShareCardFormat(this.size, this.analytics);

  final Size size;
  final ShareFormatValue analytics;
}

/// What a card shows. Strings arrive already localized, because the card renders outside the app's widget tree.
class ShareCardContent {
  const ShareCardContent({
    required this.imageUrl,
    required this.link,
    required this.brandName,
    this.contextLine,
    this.creator,
    this.creatorLine,
    this.palette = const <Color>[],
  });

  /// A display derivative or a local file. Never the original.
  final String imageUrl;
  final String link;
  final String brandName;
  final String? contextLine;

  /// The creator mark for the clean format, for example "@maya".
  final String? creator;

  /// The byline for the story and post formats, for example "by @maya".
  final String? creatorLine;

  /// Up to four stored wall colours, most dominant first.
  final List<Color> palette;
}

/// Fixed colours and sizes for the share card. The card is an image that leaves the app, so it does not follow the
/// active theme. The dark gradient is the only chrome: it keeps the text readable over any photo.
abstract final class ShareCardStyle {
  static const Color scrimEnd = Color(0xB8000000);
  static const Color scrimStart = Color(0x00000000);
  static const Color text = Color(0xFFFFFFFF);
  static const double scrimHeight = 620;
  static const double cleanScrimHeight = 360;
  static const double padding = 72;
  static const double logoSize = 96;
  static const double cleanLogoSize = 56;
  static const double dotSize = 32;
  static const int maxDots = 4;
  static const String logoAsset = 'assets/images/prism.webp';
}

/// Branded card: the wallpaper (cover crop) with either a quiet bottom band for logo, context line and link, or, in
/// the clean format, only a small mark in the corner.
class ShareCard extends StatelessWidget {
  const ShareCard({
    required this.wallpaper,
    required this.logo,
    required this.content,
    this.format = ShareCardFormat.story,
    super.key,
  });

  final ui.Image wallpaper;
  final ui.Image logo;
  final ShareCardContent content;
  final ShareCardFormat format;

  @override
  Widget build(BuildContext context) {
    final bool clean = format == ShareCardFormat.clean;
    return SizedBox.fromSize(
      size: format.size,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Proxima Nova', color: ShareCardStyle.text, decoration: TextDecoration.none),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RawImage(image: wallpaper, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: clean ? ShareCardStyle.cleanScrimHeight : ShareCardStyle.scrimHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[ShareCardStyle.scrimStart, ShareCardStyle.scrimEnd],
                  ),
                ),
              ),
            ),
            Positioned(
              left: ShareCardStyle.padding,
              right: ShareCardStyle.padding,
              bottom: ShareCardStyle.padding,
              child: clean
                  ? _CleanMark(logo: logo, creator: _trimmed(content.creator))
                  : _Band(logo: logo, content: content),
            ),
          ],
        ),
      ),
    );
  }
}

String? _trimmed(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _Band extends StatelessWidget {
  const _Band({required this.logo, required this.content});

  final ui.Image logo;
  final ShareCardContent content;

  @override
  Widget build(BuildContext context) {
    final String? line = _trimmed(content.contextLine);
    final String? byline = _trimmed(content.creatorLine);
    final String shownLink = content.link.replaceFirst(RegExp('^https?://'), '');
    final List<Color> dots = content.palette.take(ShareCardStyle.maxDots).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            RawImage(
              image: logo,
              width: ShareCardStyle.logoSize,
              height: ShareCardStyle.logoSize,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                content.brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700),
              ),
            ),
            for (final (int index, Color dot) in dots.indexed)
              Padding(
                key: ValueKey<String>('share-card-dot-$index'),
                padding: const EdgeInsets.only(left: 12),
                child: SizedBox.square(
                  dimension: ShareCardStyle.dotSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: ShareCardStyle.text.withValues(alpha: 0.6), width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final String text in <String>[?line, ?byline]) ...<Widget>[
          const SizedBox(height: 20),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 44)),
        ],
        const SizedBox(height: 12),
        Text(
          shownLink,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 40, color: ShareCardStyle.text.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _CleanMark extends StatelessWidget {
  const _CleanMark({required this.logo, required this.creator});

  final ui.Image logo;
  final String? creator;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        RawImage(
          image: logo,
          width: ShareCardStyle.cleanLogoSize,
          height: ShareCardStyle.cleanLogoSize,
          filterQuality: FilterQuality.high,
        ),
        if (creator case final String handle) ...<Widget>[
          const SizedBox(width: 20),
          Flexible(
            child: Text(
              handle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}
