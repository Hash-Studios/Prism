import 'dart:ui' as ui;

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:flutter/material.dart';

/// [crop] of [image] in the shape of [format]'s screen, inside a thin case. It is what the watch shows.
class WatchFacePreview extends StatelessWidget {
  const WatchFacePreview({
    super.key,
    required this.image,
    required this.crop,
    required this.format,
    required this.width,
    required this.semanticLabel,
  });

  final ui.Image image;
  final CropSpec crop;
  final WatchFormat format;
  final double width;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double bezel = 6;
    final Size screen = Size(width - 2 * bezel, (width - 2 * bezel) / format.aspect);
    final WatchMask mask = WatchMask(format.shape);
    final RRect body = mask.outline(Offset.zero & Size(width, screen.height + 2 * bezel));
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: screen.height + 2 * bezel,
        child: CustomPaint(
          painter: _WatchFacePainter(
            image: image,
            source: crop.sourceRect,
            mask: mask,
            body: body,
            screen: const Offset(bezel, bezel) & screen,
            caseColor: scheme.surfaceContainerHighest,
            edgeColor: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _WatchFacePainter extends CustomPainter {
  _WatchFacePainter({
    required this.image,
    required this.source,
    required this.mask,
    required this.body,
    required this.screen,
    required this.caseColor,
    required this.edgeColor,
  });

  final ui.Image image;
  final PixelRect source;
  final WatchMask mask;
  final RRect body;
  final Rect screen;
  final Color caseColor;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRRect(body, Paint()..color = caseColor)
      ..drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = edgeColor,
      )
      ..save()
      ..clipRRect(mask.outline(screen))
      ..drawImageRect(
        image,
        Rect.fromLTWH(source.left.toDouble(), source.top.toDouble(), source.width.toDouble(), source.height.toDouble()),
        screen,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_WatchFacePainter old) =>
      old.image != image ||
      old.source != source ||
      old.mask.shape != mask.shape ||
      old.body != body ||
      old.screen != screen ||
      old.caseColor != caseColor ||
      old.edgeColor != edgeColor;
}

/// A picture in a device outline: the phone at 9:19.5 and the desktop at 16:10.
class DeviceFramePreview extends StatelessWidget {
  const DeviceFramePreview({
    super.key,
    required this.child,
    required this.aspectRatio,
    required this.width,
    required this.radius,
    required this.semanticLabel,
  });

  final Widget child;
  final double aspectRatio;
  final double width;
  final double radius;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(radius + 4),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: ExcludeSemantics(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One item of the set: the preview, its name and its pixel size under it.
class SetItemTile extends StatelessWidget {
  const SetItemTile({super.key, required this.preview, required this.name, required this.size});

  final Widget preview;
  final String name;
  final String size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          preview,
          const SizedBox(height: PrismSpace.xs),
          Text(name, style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
          Text(
            size,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
