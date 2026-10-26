import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/preview/phone_frame.dart';
import 'package:Prism/features/drops/views/preview/phone_screen_overlay.dart';
import 'package:flutter/material.dart';

/// One wall in a phone, in full, under a lock screen or home screen mock.
class PreviewWallPage extends StatelessWidget {
  const PreviewWallPage({
    super.key,
    required this.wall,
    required this.mode,
    required this.now,
    required this.height,
    this.heroTag,
  });

  final DropWall wall;
  final DropPreviewMode mode;
  final DateTime now;
  final double height;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DropPhoneFrame(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PrismImageTile(url: wall.thumb, heroTag: heroTag),
            PhoneScreenOverlay(mode: mode, now: now),
          ],
        ),
      ),
    );
  }
}
