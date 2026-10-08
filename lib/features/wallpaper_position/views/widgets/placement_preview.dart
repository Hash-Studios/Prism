import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/placement_geometry.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:flutter/material.dart';

/// Matrix that puts zoomed content at the placement. It matches [PlacementGeometry.translation].
Matrix4 placementMatrix(WallpaperPlacement placement, Size image, Size frame) {
  final Size content = PlacementGeometry.contentSize(image, frame, placement.fit);
  final Offset shift = PlacementGeometry.translation(content, frame, placement);
  final double z = placement.zoom;
  return Matrix4(z, 0, 0, 0, 0, z, 0, 0, 0, 0, 1, 0, shift.dx, shift.dy, 0, 1);
}

/// The wall in a screen-shaped frame. A finger pans and zooms it. A dim layer and a lock or home layer sit on top.
///
/// The [controller] is moved to [placement] when the frame is first laid out, when its size changes and whenever
/// [syncToken] changes. A gesture changes the controller and reports through [onMoved] when it ends.
class PlacementPreview extends StatefulWidget {
  const PlacementPreview({
    super.key,
    required this.source,
    required this.placement,
    required this.syncToken,
    required this.controller,
    required this.onMoved,
  });

  final PlacementSource source;
  final WallpaperPlacement placement;
  final int syncToken;
  final TransformationController controller;

  /// Called when a gesture ends, with where the wall ended up.
  final void Function(double dx, double dy, double zoom) onMoved;

  @override
  State<PlacementPreview> createState() => _PlacementPreviewState();
}

class _PlacementPreviewState extends State<PlacementPreview> {
  int? _syncedToken;
  Size? _syncedFrame;

  Size get _image => Size(widget.source.image.width.toDouble(), widget.source.image.height.toDouble());

  void _syncIfNeeded(Size frame) {
    if (_syncedToken == widget.syncToken && _syncedFrame == frame) return;
    _syncedToken = widget.syncToken;
    _syncedFrame = frame;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.value = placementMatrix(widget.placement, _image, frame);
    });
  }

  void _moved(Size frame) {
    final Matrix4 matrix = widget.controller.value;
    final double zoom = matrix.getMaxScaleOnAxis().clamp(WallpaperPlacement.minZoom, WallpaperPlacement.maxZoom);
    final Size content = PlacementGeometry.contentSize(_image, frame, widget.placement.fit);
    final focus = PlacementGeometry.focus(Offset(matrix.storage[12], matrix.storage[13]), content, frame, zoom);
    widget.onMoved(focus.dx, focus.dy, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final WallpaperPlacement placement = widget.placement;
    final Color layerText = onColor(widget.source.dominantColor);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.secondary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size frame = constraints.biggest;
            _syncIfNeeded(frame);
            final Size content = PlacementGeometry.contentSize(_image, frame, placement.fit);
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                InteractiveViewer(
                  transformationController: widget.controller,
                  constrained: false,
                  minScale: WallpaperPlacement.minZoom,
                  maxScale: WallpaperPlacement.maxZoom,
                  onInteractionEnd: (_) => _moved(frame),
                  child: SizedBox.fromSize(
                    size: content,
                    child: _Composition(source: widget.source, fit: placement.fit, frame: frame),
                  ),
                ),
                if (placement.dim > 0)
                  IgnorePointer(
                    child: ColoredBox(color: Colors.black.withValues(alpha: placement.dim)),
                  ),
                IgnorePointer(
                  child: placement.previewMode == PlacementPreviewMode.lock
                      ? LockPreviewLayer(textColor: layerText)
                      : HomePreviewLayer(textColor: layerText),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Composition extends StatelessWidget {
  const _Composition({required this.source, required this.fit, required this.frame});

  final PlacementSource source;
  final PlacementFit fit;
  final Size frame;

  @override
  Widget build(BuildContext context) {
    final ui.Image image = source.image;
    final Size size = Size(image.width.toDouble(), image.height.toDouble());
    Widget photo(BoxFit boxFit) => RawImage(image: image, fit: boxFit, width: double.infinity);
    if (fit == PlacementFit.fill) return photo(BoxFit.fill);
    final Rect contain = PlacementGeometry.containRect(size, frame);
    final Widget background = fit == PlacementFit.fitColor
        ? ColoredBox(color: source.dominantColor)
        : ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: PlacementGeometry.blurFraction * math.min(frame.width, frame.height),
              sigmaY: PlacementGeometry.blurFraction * math.min(frame.width, frame.height),
              tileMode: TileMode.mirror,
            ),
            child: SizedBox.expand(child: photo(BoxFit.cover)),
          );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        background,
        Positioned.fromRect(rect: contain, child: photo(BoxFit.fill)),
      ],
    );
  }
}
