import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Fixed colours and sizes for the share card. The card is an image that leaves the app, so it does not follow the
/// active theme. The dark gradient is the only chrome: it keeps the text readable over any photo.
abstract final class ShareCardStyle {
  static const Size size = Size(1080, 1920);
  static const Color scrimEnd = Color(0xB8000000);
  static const Color scrimStart = Color(0x00000000);
  static const Color text = Color(0xFFFFFFFF);
  static const double scrimHeight = 620;
  static const double padding = 72;
  static const double logoSize = 96;
  static const String logoAsset = 'assets/images/prism.webp';
}

/// Branded 1080x1920 card: the wallpaper (cover crop) with a quiet bottom band for logo, context line and link.
class ShareCard extends StatelessWidget {
  const ShareCard({required this.wallpaper, required this.logo, required this.link, this.contextLine, super.key});

  final ui.Image wallpaper;
  final ui.Image logo;
  final String link;
  final String? contextLine;

  @override
  Widget build(BuildContext context) {
    final String? line = contextLine?.trim();
    final String shownLink = link.replaceFirst(RegExp('^https?://'), '');
    return SizedBox.fromSize(
      size: ShareCardStyle.size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RawImage(image: wallpaper, fit: BoxFit.cover),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: ShareCardStyle.scrimHeight,
            child: DecoratedBox(
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
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'Proxima Nova',
                color: ShareCardStyle.text,
                decoration: TextDecoration.none,
              ),
              child: Column(
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
                      const Text('Prism', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (line != null && line.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 28),
                    Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 44)),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    shownLink,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 40, color: ShareCardStyle.text.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
