import 'dart:math' as math;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum WallpaperQuickAction { favourite, share, showLess }

/// Owns the hold without navigation so the source recognizer keeps its pointer.
class WallpaperHoldRegion extends StatefulWidget {
  const WallpaperHoldRegion({
    super.key,
    required this.identity,
    required this.child,
    required this.preview,
    required this.favouriteLabel,
    required this.shareLabel,
    required this.onAction,
    this.showLessLabel,
    this.readIsFavourite,
    this.unfavouriteLabel,
  });

  final Object identity;
  final Widget child;
  final Widget preview;
  final String favouriteLabel;
  final String shareLabel;
  final String? showLessLabel;
  final bool Function()? readIsFavourite;
  final String? unfavouriteLabel;
  final ValueChanged<WallpaperQuickAction> onAction;

  @override
  State<WallpaperHoldRegion> createState() => _WallpaperHoldRegionState();
}

class _WallpaperHoldRegionState extends State<WallpaperHoldRegion> with WidgetsBindingObserver {
  OverlayEntry? _entry;
  LocalHistoryEntry? _history;
  WallpaperQuickAction? _hovered;
  int? _pointer;
  bool _saved = false;
  ScrollPosition? _scrollPosition;
  FlutterView? _view;
  (Size, double, EdgeInsets, EdgeInsets)? _viewGeometry;
  Map<WallpaperQuickAction, Offset> _centres = const <WallpaperQuickAction, Offset>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(WallpaperHoldRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity || (oldWidget.showLessLabel == null) != (widget.showLessLabel == null)) {
      _close(rebuild: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_close);
      _scrollPosition = position;
      position?.addListener(_close);
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true) || !TickerMode.valuesOf(context).enabled) {
      _close(rebuild: false);
    }
  }

  @override
  void didChangeMetrics() {
    final FlutterView? view = _view;
    if (view != null && _viewGeometry != _geometryOf(view)) _close();
  }

  (Size, double, EdgeInsets, EdgeInsets) _geometryOf(FlutterView view) => (
    view.physicalSize,
    view.devicePixelRatio,
    EdgeInsets.fromViewPadding(view.viewPadding, 1),
    EdgeInsets.fromViewPadding(view.viewInsets, 1),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _close();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_close);
    _close(rebuild: false);
    super.dispose();
  }

  void _routePointer(PointerEvent event) {
    if (event is PointerDownEvent && _pointer != null && event.pointer != _pointer) _close();
    if (event is PointerCancelEvent && event.pointer == _pointer) _close();
  }

  void _close({WallpaperQuickAction? action, bool rebuild = true}) {
    final OverlayEntry? entry = _entry;
    if (entry == null) return;
    _entry = null;
    _view = null;
    _viewGeometry = null;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_routePointer);
    entry.remove();
    entry.dispose();
    final LocalHistoryEntry? history = _history;
    _history = null;
    history?.remove();
    _hovered = null;
    _pointer = null;
    if (rebuild && mounted) setState(() {});
    if (action != null && mounted) {
      final Object identity = widget.identity;
      final ValueChanged<WallpaperQuickAction> callback = widget.onAction;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.identity == identity) callback(action);
      });
    }
  }

  void _move(Offset position) {
    if (_entry == null) return;
    final WallpaperQuickAction? hovered = _centres.entries
        .where((entry) => (entry.value - position).distance <= 24)
        .firstOrNull
        ?.key;
    if (hovered == _hovered) return;
    _hovered = hovered;
    if (hovered != null) PrismHaptics.selection();
    _entry?.markNeedsBuild();
  }

  void _open(Offset position) {
    if (_entry != null) return;
    _saved = widget.readIsFavourite?.call() ?? false;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    PrismHaptics.impact();
    final RenderBox overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset origin = overlayBox.globalToLocal(box.localToGlobal(Offset.zero));
    final Rect bounds = Offset.zero & overlayBox.size;
    final EdgeInsets padding = MediaQuery.paddingOf(overlay.context);
    final Rect safe = Rect.fromLTRB(
      padding.left + 12,
      padding.top + 12,
      bounds.right - padding.right - 12,
      bounds.bottom - padding.bottom - 12,
    );
    final Rect tile = origin & box.size;
    final Offset local = overlayBox.globalToLocal(position);
    final double direction = local.dx < safe.center.dx ? 1 : -1;
    final double vertical = local.dy - 88 < safe.top ? 1 : -1;
    final Offset anchor = Offset(
      local.dx.clamp(safe.left + 88, math.max(safe.left + 88, safe.right - 88)),
      local.dy.clamp(safe.top + 88, math.max(safe.top + 88, safe.bottom - 88)),
    );
    final List<WallpaperQuickAction> actions = <WallpaperQuickAction>[
      WallpaperQuickAction.favourite,
      WallpaperQuickAction.share,
      if (widget.showLessLabel != null) WallpaperQuickAction.showLess,
    ];
    final List<Offset> offsets = <Offset>[
      Offset(0, vertical * 64),
      Offset(direction * 50, vertical * 40),
      Offset(direction * 64, -vertical * 16),
    ];
    _centres = <WallpaperQuickAction, Offset>{for (int i = 0; i < actions.length; i++) actions[i]: anchor + offsets[i]};
    // Bound every frame of the tilt and scale, not just the unpainted layout rect.
    double paintedExtent(double side, double other) {
      final double angle = math.min(0.025, math.atan2(other, side));
      return 1.025 * (side * math.cos(angle) + other * math.sin(angle));
    }

    final double paintedWidth = paintedExtent(tile.width, tile.height);
    final double paintedHeight = paintedExtent(tile.height, tile.width);
    final double fit = math.min(1, math.min(safe.width / paintedWidth, safe.height / paintedHeight));
    final double width = tile.width * fit;
    final double height = tile.height * fit;
    final double halfWidth = paintedWidth * fit / 2;
    final double halfHeight = paintedHeight * fit / 2;
    final Rect lifted = Rect.fromLTWH(
      tile.center.dx.clamp(safe.left + halfWidth, safe.right - halfWidth) - width / 2,
      (tile.center.dy - 8).clamp(safe.top + halfHeight, safe.bottom - halfHeight) - height / 2,
      width,
      height,
    );
    final CapturedThemes themes = InheritedTheme.capture(from: context, to: overlay.context);
    _view = View.of(context);
    _viewGeometry = _geometryOf(_view!);
    _entry = OverlayEntry(builder: (overlayContext) => themes.wrap(_buildOverlay(lifted, safe, actions)));
    _history = LocalHistoryEntry(
      onRemove: () {
        _history = null;
        _close();
      },
    );
    ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_routePointer);
    overlay.insert(_entry!);
    setState(() {});
  }

  String _label(WallpaperQuickAction action) => switch (action) {
    WallpaperQuickAction.favourite => _saved ? widget.unfavouriteLabel ?? widget.favouriteLabel : widget.favouriteLabel,
    WallpaperQuickAction.share => widget.shareLabel,
    WallpaperQuickAction.showLess => widget.showLessLabel!,
  };

  Widget _buildOverlay(Rect lifted, Rect safe, List<WallpaperQuickAction> actions) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    final TextStyle? labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface);
    final TextPainter labelPainter = TextPainter(
      text: TextSpan(text: _hovered == null ? '' : _label(_hovered!), style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: safe.width - 32);
    final double labelHeight = labelPainter.height + 16;
    labelPainter.dispose();
    return BlockSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: ColoredBox(color: cs.scrim.withValues(alpha: 0.72)),
              ),
            ),
            Positioned.fromRect(
              rect: lifted,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
                    duration: reduceMotion ? Duration.zero : PrismDurations.fast,
                    curve: PrismCurves.enter,
                    builder: (context, value, child) => Transform.rotate(
                      angle: reduceMotion ? 0 : -0.025 * value,
                      child: Transform.scale(scale: reduceMotion ? 1 : 1 + 0.025 * value, child: child),
                    ),
                    child: widget.preview,
                  ),
                ),
              ),
            ),
            for (final WallpaperQuickAction action in actions)
              Positioned(
                left: _centres[action]!.dx - 24,
                top: _centres[action]!.dy - 24,
                child: Semantics(
                  button: true,
                  label: _label(action),
                  selected: action == _hovered,
                  child: SizedBox.square(
                    dimension: 48,
                    child: ClipOval(
                      child: Material(
                        color: action == _hovered ? cs.primary : cs.surfaceContainerHighest,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _close(action: action),
                          child: Icon(switch (action) {
                            WallpaperQuickAction.favourite =>
                              _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            WallpaperQuickAction.share => Icons.ios_share_rounded,
                            WallpaperQuickAction.showLess => Icons.visibility_off_outlined,
                          }, color: action == _hovered ? cs.onPrimary : cs.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_hovered case final WallpaperQuickAction action)
              Positioned(
                left: safe.left,
                width: safe.width,
                top: (_centres.values.map((p) => p.dy).reduce(math.max) + 44).clamp(
                  safe.top,
                  math.max(safe.top, safe.bottom - labelHeight),
                ),
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(_label(action), textAlign: TextAlign.center, style: labelStyle),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_entry == null) {
        _pointer = event.pointer;
      } else if (event.pointer != _pointer) {
        _close();
      }
    },
    child: Semantics(
      container: true,
      onLongPress: () {
        _pointer = null;
        final RenderBox box = context.findRenderObject()! as RenderBox;
        _open(box.localToGlobal(box.size.center(Offset.zero)));
      },
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (details) => _open(details.globalPosition),
        onLongPressMoveUpdate: (details) {
          final RenderBox overlayBox = Overlay.of(context, rootOverlay: true).context.findRenderObject()! as RenderBox;
          _move(overlayBox.globalToLocal(details.globalPosition));
        },
        onLongPressEnd: (details) {
          if (_entry == null) return;
          final RenderBox overlayBox = Overlay.of(context, rootOverlay: true).context.findRenderObject()! as RenderBox;
          _move(overlayBox.globalToLocal(details.globalPosition));
          _close(action: _hovered);
        },
        onLongPressCancel: _close,
        child: Opacity(opacity: _entry == null ? 1 : 0, child: widget.child),
      ),
    ),
  );
}
