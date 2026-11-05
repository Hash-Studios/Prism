import 'dart:math' as math;

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/views/preview/phone_frame.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter/material.dart';

/// The wall in a phone frame, moving like the Live Photo will. It follows the same `sin(phase)` and `sin(2 phase)`
/// paths as `PrismLivePhotoRenderer.swift`, so the still pose matches the key photo. With reduce motion it holds that
/// still pose.
class LivePhotoPreview extends StatefulWidget {
  const LivePhotoPreview({super.key, required this.image, required this.style, required this.tint, this.height = 240});

  final ImageProvider? image;
  final MotionStyle style;
  final Color tint;
  final double height;

  @override
  State<LivePhotoPreview> createState() => _LivePhotoPreviewState();
}

class _LivePhotoPreviewState extends State<LivePhotoPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: LiveExport.maxDuration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _loop
        ..stop()
        ..value = 0;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ImageProvider? image = widget.image;
    return ExcludeSemantics(
      child: DropPhoneFrame(
        height: widget.height,
        child: image == null
            ? ColoredBox(color: scheme.surfaceContainerHigh)
            : LayoutBuilder(
                builder: (context, constraints) => RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _loop,
                    builder: (context, child) => _frame(child!, _loop.value, constraints.biggest),
                    child: Image(image: image, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _frame(Widget photo, double phase, Size size) {
    final double a = 2 * math.pi * phase;
    switch (widget.style) {
      case MotionStyle.drift:
        return _placed(photo, size, zoom: 1.12 + 0.03 * math.sin(a), pan: Offset(math.sin(a), math.sin(2 * a)) * 0.022);
      case MotionStyle.breathe:
        final double pulse = math.sin(a);
        final double gain = 1 + 0.035 * pulse;
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            gain, 0, 0, 0, 0, //
            0, gain, 0, 0, 0, //
            0, 0, gain, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: _placed(photo, size, zoom: 1.08 + 0.025 * pulse, pan: Offset.zero),
        );
      case MotionStyle.shimmer:
        final double x = (phase * 2) % 1;
        final double sweep = x * x * (3 - 2 * x);
        final double centre = (-0.6 + sweep * 2.6) / 1.4;
        final Color glow = Color.lerp(Colors.white, widget.tint, 0.25)!.withValues(alpha: 0.35);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _placed(photo, size, zoom: 1.05, pan: Offset.zero),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: <Color>[glow.withValues(alpha: 0), glow, glow.withValues(alpha: 0)],
                  stops: <double>[
                    (centre - 0.12).clamp(0.0, 1.0),
                    centre.clamp(0.0, 1.0),
                    (centre + 0.12).clamp(0.0, 1.0),
                  ],
                ),
              ),
            ),
          ],
        );
      case MotionStyle.depth:
        return _placed(photo, size, zoom: 1.04, pan: Offset(math.sin(a), 0.5 * math.sin(2 * a)) * 0.012);
      case MotionStyle.ripple:
        return photo;
    }
  }

  /// [pan] is in texture units with y up, as in the shader. Moving the sample point right moves the picture left.
  Widget _placed(Widget photo, Size size, {required double zoom, required Offset pan}) => ClipRect(
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(-pan.dx * size.width * zoom, pan.dy * size.height * zoom, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1),
      child: photo,
    ),
  );
}
