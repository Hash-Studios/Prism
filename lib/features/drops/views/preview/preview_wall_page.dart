import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/preview/phone_frame.dart';
import 'package:Prism/features/drops/views/preview/phone_screen_overlay.dart';
import 'package:Prism/features/drops/views/preview/preview_painters.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One wall in a phone. While [owned] is false a watermark and a light frost sit over it. When it turns true they
/// fade out under one gold sheen.
class PreviewWallPage extends StatefulWidget {
  const PreviewWallPage({
    super.key,
    required this.wall,
    required this.owned,
    required this.mode,
    required this.now,
    required this.height,
    this.heroTag,
  });

  final DropWall wall;
  final bool owned;
  final DropPreviewMode mode;
  final DateTime now;
  final double height;
  final String? heroTag;

  @override
  State<PreviewWallPage> createState() => _PreviewWallPageState();
}

class _PreviewWallPageState extends State<PreviewWallPage> with SingleTickerProviderStateMixin {
  static const double _fadeShare = 0.55;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: widget.owned ? 1 : 0,
  );

  @override
  void didUpdateWidget(PreviewWallPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owned == widget.owned) return;
    if (!widget.owned) {
      _reveal.value = 0;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DropPhoneFrame(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) {
            final double veil = 1 - Curves.easeOut.transform((_reveal.value / _fadeShare).clamp(0, 1));
            final double frost = 1.6 * veil;
            Widget image = PrismImageTile(url: widget.wall.thumb, heroTag: widget.heroTag);
            if (frost > 0.01) {
              image = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: frost, sigmaY: frost, tileMode: TileMode.clamp),
                child: image,
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                image,
                PhoneScreenOverlay(mode: widget.mode, now: widget.now),
                IgnorePointer(
                  child: CustomPaint(
                    painter: DropWatermarkPainter(opacity: veil, label: context.l10n.economyDropWatermarkLabel),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(painter: DropSheenPainter(progress: _reveal.value)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
