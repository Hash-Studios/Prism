import 'dart:math' as math;

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The whole image with the crop frame on top. The frame is white on a black scrim, as all chrome on a wallpaper is.
/// Drag inside the frame to move it, pinch to resize it, or drag a corner.
///
/// [image] is drawn as the source, before the turn. Every gesture starts from the spec it began with and applies the
/// total movement since then, so no rounding builds up.
class CropFrameView extends StatefulWidget {
  const CropFrameView({super.key, required this.spec, required this.image, required this.onChanged, this.window});

  final CropSpec spec;
  final Widget image;
  final ValueChanged<CropSpec> onChanged;

  /// The part of the frame that stays clear, such as the screen of a watch. The rest of the frame is dimmed too.
  /// Null keeps the whole frame clear.
  final RRect Function(Rect frame)? window;

  /// Half the hit target of a corner handle, so a handle on the image edge stays inside the view.
  static const double handleInset = 24;

  /// Screen points per view pixel when [spec]'s whole view fits in [size], inside the handle inset.
  static double fitScale(CropSpec spec, Size size) {
    final double scale = math.min(
      (size.width - 2 * handleInset) / spec.viewWidth,
      (size.height - 2 * handleInset) / spec.viewHeight,
    );
    return scale.isFinite && scale > 0 ? scale : 0;
  }

  @override
  State<CropFrameView> createState() => _CropFrameViewState();
}

class _CropFrameViewState extends State<CropFrameView> with SingleTickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(vsync: this);
  Rect _from = Rect.zero;
  Rect _to = Rect.zero;
  CropSpec? _gestureStart;
  Offset _gestureDelta = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _to = _rectOf(widget.spec);
    _snap.value = 1;
  }

  @override
  void didUpdateWidget(CropFrameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Rect next = _rectOf(widget.spec);
    if (next == _to) return;
    final bool sameView = oldWidget.spec.quarterTurns == widget.spec.quarterTurns;
    final Duration duration = context.motion(PrismDurations.base);
    if (_dragging || !sameView || duration == Duration.zero) {
      _snap.value = 1;
      _from = _to = next;
      return;
    }
    _from = _shown;
    _to = next;
    _snap
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  Rect get _shown => Rect.lerp(_from, _to, PrismCurves.move.transform(_snap.value))!;

  static Rect _rectOf(CropSpec spec) => Rect.fromLTWH(
    spec.rect.left.toDouble(),
    spec.rect.top.toDouble(),
    spec.rect.width.toDouble(),
    spec.rect.height.toDouble(),
  );

  void _begin() {
    _gestureStart = widget.spec;
    _gestureDelta = Offset.zero;
    setState(() => _dragging = true);
  }

  void _end() {
    _gestureStart = null;
    setState(() => _dragging = false);
  }

  CropSpec _stepped(CropCorner corner, double step) => widget.spec.resized(corner, corner.sx * step, corner.sy * step);

  @override
  Widget build(BuildContext context) {
    final CropSpec spec = widget.spec;
    final AppLocalizations l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        const double inset = CropFrameView.handleInset;
        final double scale = CropFrameView.fitScale(spec, constraints.biggest);
        if (scale <= 0) return const SizedBox.shrink();
        final Size box = Size(spec.viewWidth * scale, spec.viewHeight * scale);
        final Offset origin = Offset((constraints.maxWidth - box.width) / 2, (constraints.maxHeight - box.height) / 2);
        final double step = math.min(spec.viewWidth, spec.viewHeight) * 0.05;
        String sizeOf(CropSpec next) => l10n.wallpaperCropSize(next.outputWidth, next.outputHeight);
        return AnimatedBuilder(
          animation: _snap,
          builder: (context, _) {
            final Rect frame = Rect.fromLTRB(
              _shown.left * scale,
              _shown.top * scale,
              _shown.right * scale,
              _shown.bottom * scale,
            ).shift(origin);
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: origin & box,
                  child: RotatedBox(quarterTurns: spec.quarterTurns, child: widget.image),
                ),
                Positioned.fill(
                  child: Semantics(
                    label: l10n.wallpaperCropArea,
                    value: sizeOf(spec),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (_) => _begin(),
                      onScaleUpdate: (details) {
                        final CropSpec? start = _gestureStart;
                        if (start == null) return;
                        _gestureDelta += details.focalPointDelta / scale;
                        final CropSpec scaled = details.pointerCount > 1 ? start.scaled(details.scale) : start;
                        widget.onChanged(scaled.moved(_gestureDelta.dx, _gestureDelta.dy));
                      },
                      onScaleEnd: (_) => _end(),
                      child: CustomPaint(
                        painter: _CropPainter(
                          frame: frame,
                          window: widget.window?.call(frame),
                          image: origin & box,
                          scrim: Colors.black.withValues(alpha: 0.55),
                          line: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: frame,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _dragging ? 1 : 0,
                      duration: context.motion(PrismDurations.fast),
                      curve: PrismCurves.enter,
                      child: CustomPaint(painter: _ThirdsPainter(Colors.white.withValues(alpha: 0.6))),
                    ),
                  ),
                ),
                for (final CropCorner corner in CropCorner.values)
                  Positioned(
                    left: (corner.sx < 0 ? frame.left : frame.right) - inset,
                    top: (corner.sy < 0 ? frame.top : frame.bottom) - inset,
                    width: inset * 2,
                    height: inset * 2,
                    child: Semantics(
                      label: switch (corner) {
                        CropCorner.topLeft => l10n.wallpaperCropCornerTopLeft,
                        CropCorner.topRight => l10n.wallpaperCropCornerTopRight,
                        CropCorner.bottomLeft => l10n.wallpaperCropCornerBottomLeft,
                        CropCorner.bottomRight => l10n.wallpaperCropCornerBottomRight,
                      },
                      value: sizeOf(spec),
                      increasedValue: sizeOf(_stepped(corner, step)),
                      decreasedValue: sizeOf(_stepped(corner, -step)),
                      onIncrease: () => widget.onChanged(_stepped(corner, step)),
                      onDecrease: () => widget.onChanged(_stepped(corner, -step)),
                      child: GestureDetector(
                        key: ValueKey<CropCorner>(corner),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => _begin(),
                        onPanUpdate: (details) {
                          final CropSpec? start = _gestureStart;
                          if (start == null) return;
                          _gestureDelta += details.delta / scale;
                          widget.onChanged(start.resized(corner, _gestureDelta.dx, _gestureDelta.dy));
                        },
                        onPanEnd: (_) => _end(),
                        onPanCancel: _end,
                        child: CustomPaint(painter: _CornerPainter(corner, Colors.white)),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({required this.frame, this.window, required this.image, required this.scrim, required this.line});

  final Rect frame;
  final RRect? window;
  final Rect image;
  final Color scrim;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect? window = this.window;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(image),
        window == null ? (Path()..addRect(frame)) : (Path()..addRRect(window)),
      ),
      Paint()..color = scrim,
    );
    if (window != null) {
      canvas.drawRRect(
        window.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = line,
      );
    }
    canvas
      ..drawRect(
        frame.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black.withValues(alpha: 0.25),
      )
      ..drawRect(
        frame.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = line,
      );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.frame != frame || old.window != window || old.image != image || old.scrim != scrim || old.line != line;
}

class _ThirdsPainter extends CustomPainter {
  _ThirdsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      final double x = size.width * i / 3;
      final double y = size.height * i / 3;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), paint)
        ..drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter old) => old.color != color;
}

/// An L at the frame corner, in the middle of the handle's hit target.
class _CornerPainter extends CustomPainter {
  _CornerPainter(this.corner, this.color);

  final CropCorner corner;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double arm = 18;
    final Offset c = size.center(Offset.zero);
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final double inX = -corner.sx * arm;
    final double inY = -corner.sy * arm;
    final Path path = Path()
      ..moveTo(c.dx + inX, c.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(c.dx, c.dy + inY);
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      )
      ..drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.corner != corner || old.color != color;
}
