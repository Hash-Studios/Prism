import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// The target frame with the canvas shape of [canvas]: 60% of the screen height at most, and never over 640.
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({super.key, required this.canvas, required this.child});

  final PhotoSize canvas;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double maxHeight = (MediaQuery.sizeOf(context).height * 0.6).clamp(240.0, 640.0);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: canvas.aspect,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PrismRadius.md),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(PrismRadius.md), child: child),
          ),
        ),
      ),
    );
  }
}

/// The photo inside the empty canvas, where [placement] puts it. The empty part is what AI fills in.
class PhotoInCanvas extends StatelessWidget {
  const PhotoInCanvas({super.key, required this.source, required this.placement});

  final PhotoSource source;
  final PhotoPlacement placement;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double k = box.maxWidth / placement.canvas.width;
        final int cacheWidth = (placement.width * k * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, 4096);
        // Opaque: in the compare view this sits on top of the result, which must not show through the empty canvas.
        return ColoredBox(
          color: Color.alphaBlend(cs.onSurface.withValues(alpha: 0.06), cs.surface),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: placement.left * k,
                top: placement.top * k,
                width: placement.width * k,
                height: placement.height * k,
                child: Image.memory(source.bytes, fit: BoxFit.cover, cacheWidth: cacheWidth, gaplessPlayback: true),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Drag to move the photo, pinch to make it smaller. Screen readers get move actions instead of the gestures.
class PhotoPlacementFrame extends StatefulWidget {
  const PhotoPlacementFrame({
    super.key,
    required this.source,
    required this.placement,
    required this.onChanged,
    this.enabled = true,
  });

  final PhotoSource source;
  final PhotoPlacement placement;
  final ValueChanged<PhotoPlacement> onChanged;
  final bool enabled;

  @override
  State<PhotoPlacementFrame> createState() => _PhotoPlacementFrameState();
}

class _PhotoPlacementFrameState extends State<PhotoPlacementFrame> {
  double _lastScale = 1;

  /// The newest placement, ahead of the rebuild, so fast updates in one frame do not start from a stale value.
  late PhotoPlacement _live = widget.placement;

  @override
  void didUpdateWidget(PhotoPlacementFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _live = widget.placement;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PhotoPlacement placement = widget.placement;
    final ValueChanged<PhotoPlacement> onChanged = widget.onChanged;
    final bool enabled = widget.enabled;
    return PhotoFrame(
      canvas: placement.canvas,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double k = box.maxWidth / placement.canvas.width;
          return Semantics(
            label: l10n.photoWallPlaceSemantics,
            customSemanticsActions: enabled
                ? <CustomSemanticsAction, VoidCallback>{
                    CustomSemanticsAction(label: l10n.photoWallPlaceMoveStart): () => onChanged(placement.alignedTo(0)),
                    CustomSemanticsAction(label: l10n.photoWallPlaceMoveCentre): () =>
                        onChanged(placement.alignedTo(0.5)),
                    CustomSemanticsAction(label: l10n.photoWallPlaceMoveEnd): () => onChanged(placement.alignedTo(1)),
                  }
                : null,
            child: RawGestureDetector(
              key: const ValueKey<String>('photo-placement'),
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                if (enabled)
                  _ClaimingScaleRecognizer: GestureRecognizerFactoryWithHandlers<_ClaimingScaleRecognizer>(
                    _ClaimingScaleRecognizer.new,
                    (_ClaimingScaleRecognizer r) => r
                      ..onStart = ((_) => _lastScale = 1)
                      ..onUpdate = (ScaleUpdateDetails d) {
                        PhotoPlacement next = _live.moved(d.focalPointDelta.dx / k, d.focalPointDelta.dy / k);
                        if (d.pointerCount > 1 && d.scale > 0) {
                          next = next.scaled(d.scale / _lastScale);
                          _lastScale = d.scale;
                        }
                        if (next == _live) return;
                        _live = next;
                        onChanged(next);
                      },
                  ),
              },
              child: PhotoInCanvas(source: widget.source, placement: placement),
            ),
          );
        },
      ),
    );
  }
}

/// Before and after in one frame. The divider follows a horizontal drag; screen readers adjust it like a slider.
class PhotoCompareView extends StatefulWidget {
  const PhotoCompareView({super.key, required this.canvas, required this.before, required this.after});

  final PhotoSize canvas;
  final Widget before;
  final Widget after;

  @override
  State<PhotoCompareView> createState() => _PhotoCompareViewState();
}

class _PhotoCompareViewState extends State<PhotoCompareView> with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(vsync: this)..addListener(_onGlide);
  Animation<double>? _glideTo;
  double _split = 0.5;

  void _set(double value) {
    _glide.stop();
    setState(() => _split = value.clamp(0.0, 1.0));
  }

  /// A tap moves the divider to the finger with a short ease-out, so it does not jump. A drag follows the finger.
  void _glideToValue(double value) {
    final Duration duration = context.motion(PrismDurations.fast);
    if (duration == Duration.zero) return _set(value);
    _glideTo = Tween<double>(
      begin: _split,
      end: value.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _glide, curve: PrismCurves.enter));
    _glide
      ..duration = duration
      ..forward(from: 0);
  }

  void _onGlide() {
    final Animation<double>? to = _glideTo;
    if (to != null) setState(() => _split = to.value);
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextStyle label = PrismTextStyles.caption(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700);
    return PhotoFrame(
      canvas: widget.canvas,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double x = box.maxWidth * _split;
          return Semantics(
            label: l10n.photoWallCompareSemantics,
            slider: true,
            value: '${(_split * 100).round()}%',
            increasedValue: '${((_split + 0.1).clamp(0.0, 1.0) * 100).round()}%',
            decreasedValue: '${((_split - 0.1).clamp(0.0, 1.0) * 100).round()}%',
            onIncrease: () => _set(_split + 0.1),
            onDecrease: () => _set(_split - 0.1),
            child: GestureDetector(
              key: const ValueKey<String>('photo-compare'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (DragUpdateDetails d) => _set(d.localPosition.dx / box.maxWidth),
              onTapDown: (TapDownDetails d) => _glideToValue(d.localPosition.dx / box.maxWidth),
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    widget.after,
                    ClipRect(clipper: _LeftOf(x), child: widget.before),
                    Positioned(
                      left: x - 1,
                      top: 0,
                      bottom: 0,
                      child: const SizedBox(width: 2, child: ColoredBox(color: Colors.white)),
                    ),
                    Positioned(
                      left: x - 18,
                      top: box.maxHeight / 2 - 18,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.unfold_more_rounded, color: Colors.black, size: 20),
                      ),
                    ),
                    Positioned(left: PrismSpace.xs, top: PrismSpace.xs, child: _Pill(l10n.photoWallBefore, label)),
                    Positioned(right: PrismSpace.xs, top: PrismSpace.xs, child: _Pill(l10n.photoWallAfter, label)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Takes the pointer on touch-down, so a drag that starts on the photo moves the photo and not the page.
class _ClaimingScaleRecognizer extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _LeftOf extends CustomClipper<Rect> {
  const _LeftOf(this.x);

  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(_LeftOf old) => old.x != x;
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(PrismRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: PrismSpace.xxs),
      child: Text(text, style: style),
    ),
  );
}

/// What Prism will do with the photo, or that the photo already fits.
class PhotoPlanCard extends StatelessWidget {
  const PhotoPlanCard({super.key, required this.mode, required this.target, this.styleLabel});

  final PhotoJobMode? mode;
  final PhotoJobTarget target;

  /// The style name for Restyle.
  final String? styleLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool desktop = target == PhotoJobTarget.desktop;
    final (IconData icon, String title, String detail) = switch (mode) {
      PhotoJobMode.extend => (
        Icons.open_in_full_rounded,
        desktop ? l10n.photoWallPlanExtendDesktop : l10n.photoWallPlanExtend,
        l10n.photoWallPlanExtendDetail,
      ),
      PhotoJobMode.upscale => (Icons.auto_awesome_rounded, l10n.photoWallPlanUpscale, l10n.photoWallPlanUpscaleDetail),
      PhotoJobMode.restyle => (
        Icons.palette_rounded,
        l10n.photoWallPlanRestyle(styleLabel ?? ''),
        l10n.photoWallPlanRestyleDetail,
      ),
      null => (
        Icons.check_circle_rounded,
        desktop ? l10n.photoWallPlanFitsDesktop : l10n.photoWallPlanFits,
        l10n.photoWallPlanFitsDetail,
      ),
    };
    return PrismCard(
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: PrismTextStyles.cardTitle(context)),
                  const SizedBox(height: PrismSpace.xxs),
                  Text(detail, style: PrismTextStyles.body(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "From your photo" entry on the AI tab.
class AiFromPhotoCard extends StatelessWidget {
  const AiFromPhotoCard({super.key, required this.onTap, this.enabled = true});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismCard(
      onTap: enabled ? onTap : null,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Row(
          children: <Widget>[
            Icon(Icons.add_photo_alternate_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.photoWallEntryTitle, style: PrismTextStyles.cardTitle(context)),
                  Text(l10n.photoWallEntrySubtitle, style: PrismTextStyles.body(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
