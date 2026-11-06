import 'dart:math' as math;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/gesture_hint.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum WallpaperQuickAction { favourite, share, showLess, resetOriginal, saveToFolder, pin, dayNight }

enum _HoldPhase { idle, entering, open, exiting }

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
    this.resetOriginalLabel,
    this.readIsFavourite,
    this.unfavouriteLabel,
    this.saveToFolderLabel,
    this.pinLabel,
    this.unpinLabel,
    this.readIsPinned,
    this.dayNightLabel,
    this.tone,
  });

  final Object identity;
  final Widget child;
  final Widget preview;
  final String favouriteLabel;
  final String shareLabel;
  final String? showLessLabel;
  final String? resetOriginalLabel;
  final bool Function()? readIsFavourite;
  final String? unfavouriteLabel;
  final String? saveToFolderLabel;
  final String? pinLabel;
  final String? unpinLabel;

  /// Read when the menu opens. Null hides Pin, as for a wall that is not a favourite.
  final bool? Function()? readIsPinned;
  final ValueChanged<WallpaperQuickAction> onAction;

  /// Null hides Day and night: on Android, and on iOS before 16.
  final String? dayNightLabel;

  /// The wall's main colour. A dark one gets a white press ring. Null uses the theme's ink over a light wash.
  final Color? tone;

  @override
  State<WallpaperHoldRegion> createState() => _WallpaperHoldRegionState();
}

class _WallpaperHoldRegionState extends State<WallpaperHoldRegion>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Fills over the long-press timeout from touch-down, so the hold shows progress before the menu opens.
  late final AnimationController _ring = AnimationController(vsync: this, duration: kLongPressTimeout);
  Offset _touch = Offset.zero;
  Offset? _ringDown;
  OverlayEntry? _entry;
  LocalHistoryEntry? _history;
  WallpaperQuickAction? _hovered;
  _HoldPhase _phase = _HoldPhase.idle;
  bool _reduceMotion = false;
  int? _pointer;
  bool _saved = false;
  bool? _pinned;
  ScrollPosition? _scrollPosition;
  FlutterView? _view;
  (Size, double, EdgeInsets, EdgeInsets)? _viewGeometry;
  Map<WallpaperQuickAction, Offset> _centres = const <WallpaperQuickAction, Offset>{};
  Offset _anchor = Offset.zero;

  /// The menu's progress when the close began, so the fold toward the finger starts from where the buttons are.
  double? _exitFrom;
  int _actionDispatchGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(WallpaperHoldRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        (oldWidget.showLessLabel == null) != (widget.showLessLabel == null) ||
        (oldWidget.resetOriginalLabel == null) != (widget.resetOriginalLabel == null) ||
        (oldWidget.saveToFolderLabel == null) != (widget.saveToFolderLabel == null) ||
        (oldWidget.dayNightLabel == null) != (widget.dayNightLabel == null)) {
      _close(rebuild: false, animate: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_closeForScroll);
      _scrollPosition = position;
      position?.addListener(_closeForScroll);
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true) || !TickerMode.valuesOf(context).enabled) {
      _close(rebuild: false, animate: false);
    }
  }

  @override
  void didChangeMetrics() {
    final FlutterView? view = _view;
    if (view != null && _viewGeometry != _geometryOf(view)) _close(animate: false);
  }

  (Size, double, EdgeInsets, EdgeInsets) _geometryOf(FlutterView view) => (
    view.physicalSize,
    view.devicePixelRatio,
    EdgeInsets.fromViewPadding(view.viewPadding, 1),
    EdgeInsets.fromViewPadding(view.viewInsets, 1),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _close(animate: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_closeForScroll);
    _close(rebuild: false, animate: false);
    _ring.dispose();
    super.dispose();
  }

  void _routePointer(PointerEvent event) {
    if (event is PointerDownEvent && _pointer != null && event.pointer != _pointer) _close(animate: false);
    // The system took the touch: settle like a lift, without an action.
    if (event is PointerCancelEvent && event.pointer == _pointer) _close();
  }

  void _closeForScroll() {
    _releaseRing();
    _close(animate: false);
  }

  /// A lift, a drag or a scroll before the timeout: the ring unwinds and fades.
  void _releaseRing() {
    _ringDown = null;
    if (_ring.value > 0 || _ring.isAnimating) {
      _ring.animateBack(0, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    }
  }

  void _close({WallpaperQuickAction? action, bool rebuild = true, bool animate = true}) {
    if (!animate) _actionDispatchGeneration++;
    final OverlayEntry? entry = _entry;
    if (entry == null) return;
    if (_phase == _HoldPhase.exiting) {
      if (!animate) {
        _finishClose(rebuild: rebuild);
      }
      return;
    }
    _phase = _HoldPhase.exiting;
    _view = null;
    _viewGeometry = null;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_routePointer);
    final LocalHistoryEntry? history = _history;
    _history = null;
    history?.remove();
    // An animated close keeps the chosen action lit while it fades; an instant one clears it now.
    if (!animate || _reduceMotion) _hovered = null;
    _pointer = null;
    if (rebuild && mounted) setState(() {});
    if (action != null && mounted) {
      final Object identity = widget.identity;
      final ValueChanged<WallpaperQuickAction> callback = widget.onAction;
      final int generation = ++_actionDispatchGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.identity == identity && _actionDispatchGeneration == generation) {
          callback(action);
        }
      });
    }
    if (!animate || _reduceMotion) {
      _finishClose(rebuild: rebuild);
    } else {
      entry.markNeedsBuild();
    }
  }

  void _finishClose({bool rebuild = true}) {
    final OverlayEntry? entry = _entry;
    if (entry == null) return;
    _entry = null;
    _phase = _HoldPhase.idle;
    _hovered = null;
    entry.remove();
    entry.dispose();
    if (rebuild && mounted) setState(() {});
  }

  void _move(Offset position) {
    if (_entry == null || _phase == _HoldPhase.exiting) return;
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
    if (_entry != null || _phase != _HoldPhase.idle) return;
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    _ringDown = null;
    _ring.value = 0;
    _saved = widget.readIsFavourite?.call() ?? false;
    _pinned = widget.pinLabel == null ? null : widget.readIsPinned?.call();
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    PrismHaptics.impact();
    GestureHints.markSeen(GestureHint.holdToSave);
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
      if (widget.resetOriginalLabel != null) WallpaperQuickAction.resetOriginal,
      if (widget.saveToFolderLabel != null) WallpaperQuickAction.saveToFolder,
      if (_pinned != null) WallpaperQuickAction.pin,
      if (widget.dayNightLabel != null) WallpaperQuickAction.dayNight,
    ];
    assert(actions.length <= 6, 'The hold ring has six positions');
    final List<Offset> offsets = <Offset>[
      Offset(0, vertical * 64),
      Offset(direction * 50, vertical * 40),
      Offset(direction * 64, -vertical * 16),
      Offset(-direction * 50, vertical * 40),
      Offset(-direction * 64, -vertical * 16),
      Offset(0, -vertical * 64),
    ];
    _anchor = anchor;
    _exitFrom = null;
    _centres = <WallpaperQuickAction, Offset>{for (int i = 0; i < actions.length; i++) actions[i]: anchor + offsets[i]};
    // Bound every frame of the tilt and scale, not just the unpainted layout rect.
    double paintedExtent(double side, double other) {
      final double angle = math.min(0.025, math.atan2(other, side));
      return 1.025 * (side * math.cos(angle) + other * math.sin(angle));
    }

    final double paintedWidth = paintedExtent(tile.width, tile.height);
    final double paintedHeight = paintedExtent(tile.height, tile.width);
    final double fit = math.min(1, math.min(safe.width / paintedWidth, (safe.height - 16) / paintedHeight));
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
    _phase = _reduceMotion ? _HoldPhase.open : _HoldPhase.entering;
    setState(() {});
  }

  String _label(WallpaperQuickAction action) => switch (action) {
    WallpaperQuickAction.favourite => _saved ? widget.unfavouriteLabel ?? widget.favouriteLabel : widget.favouriteLabel,
    WallpaperQuickAction.share => widget.shareLabel,
    WallpaperQuickAction.showLess => widget.showLessLabel!,
    WallpaperQuickAction.resetOriginal => widget.resetOriginalLabel!,
    WallpaperQuickAction.saveToFolder => widget.saveToFolderLabel!,
    WallpaperQuickAction.pin => _pinned == true ? widget.unpinLabel ?? widget.pinLabel! : widget.pinLabel!,
    WallpaperQuickAction.dayNight => widget.dayNightLabel!,
  };

  Widget _buildOverlay(Rect lifted, Rect safe, List<WallpaperQuickAction> actions) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool reduceMotion = _reduceMotion;
    // Light themes wash the rest of the screen toward the page, so the lifted wall reads as the one thing left. Dark
    // themes keep a dark scrim: a light wash there would glare.
    final bool wash = theme.brightness == Brightness.light;
    final TextStyle? labelStyle = theme.textTheme.titleLarge?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
    );
    final TextPainter labelPainter = TextPainter(
      text: TextSpan(text: _hovered == null ? '' : _label(_hovered!), style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: safe.width - 32);
    final double labelHeight = labelPainter.height + 20;
    labelPainter.dispose();
    // The label sits above the ring, where the finger does not cover it. Below only when the top has no room.
    final double ringTop = _centres.values.map((p) => p.dy).reduce(math.min) - 24;
    final double ringBottom = _centres.values.map((p) => p.dy).reduce(math.max) + 24;
    final double labelTop = ringTop - 12 - labelHeight >= safe.top ? ringTop - 12 - labelHeight : ringBottom + 12;
    return TickerMode(
      enabled: true,
      child: _HoldMotion(
        exiting: _phase == _HoldPhase.exiting,
        reduceMotion: reduceMotion,
        onEntered: () {
          if (_phase == _HoldPhase.entering) _phase = _HoldPhase.open;
        },
        onDismissed: _finishClose,
        builder: (progress) {
          // 0 until the close starts, then 1 when it ends. Only the close moves the buttons, so a finger that aims at
          // a button while the menu opens finds it where it lands.
          double fold = 0;
          if (_phase == _HoldPhase.exiting) {
            final double from = _exitFrom ??= progress;
            fold = progress >= from ? 0 : 1 - progress / from;
          }
          return IgnorePointer(
            ignoring: _phase == _HoldPhase.exiting,
            child: BlockSemantics(
              child: Material(
                type: MaterialType.transparency,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _close,
                        child: ColoredBox(
                          key: const ValueKey<String>('wallpaper-hold-scrim'),
                          color: wash
                              ? cs.surface.withValues(alpha: 0.82 * progress)
                              : cs.scrim.withValues(alpha: 0.72 * progress),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: lifted,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: Transform.translate(
                            offset: Offset(0, reduceMotion ? 0 : 8 * (1 - progress)),
                            child: Transform.rotate(
                              angle: reduceMotion ? 0 : -0.025 * progress,
                              child: Transform.scale(
                                scale: reduceMotion ? 1 : 1 + 0.025 * progress,
                                child: DecoratedBox(
                                  key: const ValueKey<String>('wallpaper-hold-lift-shadow'),
                                  decoration: BoxDecoration(
                                    borderRadius: PrismWallGrid.tileRadius,
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18 * progress),
                                        offset: const Offset(0, 12),
                                        blurRadius: 28,
                                      ),
                                    ],
                                  ),
                                  child: widget.preview,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final WallpaperQuickAction action in actions)
                      Positioned(
                        left: _centres[action]!.dx - 24,
                        top: _centres[action]!.dy - 24,
                        child: _buildAction(action, actions.indexOf(action), reduceMotion, progress, fold, cs),
                      ),
                    if (_hovered case final WallpaperQuickAction action)
                      Positioned(
                        left: safe.left,
                        width: safe.width,
                        top: labelTop.clamp(safe.top, math.max(safe.top, safe.bottom - labelHeight)),
                        child: IgnorePointer(
                          child: Center(
                            child: Opacity(
                              opacity: progress,
                              child: DecoratedBox(
                                key: const ValueKey<String>('wallpaper-hold-label'),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  child: Text(_label(action), textAlign: TextAlign.center, style: labelStyle),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAction(
    WallpaperQuickAction action,
    int index,
    bool reduceMotion,
    double progress,
    double fold,
    ColorScheme cs,
  ) {
    final double staggered = reduceMotion
        ? 1
        : PrismCurves.enter.transform(((progress - index * 0.08) / (1 - index * 0.08)).clamp(0, 1));
    return Opacity(
      opacity: staggered,
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        // Back toward the finger as the menu closes.
        offset: (_anchor - _centres[action]!) * (0.5 * fold),
        child: Transform.scale(
          scale: 0.84 + 0.16 * staggered - 0.24 * fold,
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
                  animationDuration: const Duration(milliseconds: 100),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _close(action: action),
                    child: Icon(switch (action) {
                      WallpaperQuickAction.favourite => _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      WallpaperQuickAction.share => Icons.ios_share_rounded,
                      WallpaperQuickAction.showLess => Icons.visibility_off_outlined,
                      WallpaperQuickAction.resetOriginal => Icons.restart_alt_rounded,
                      WallpaperQuickAction.saveToFolder => Icons.create_new_folder_rounded,
                      WallpaperQuickAction.pin => _pinned == true ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      WallpaperQuickAction.dayNight => Icons.contrast_rounded,
                    }, color: action == _hovered ? cs.onPrimary : cs.onSurface),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _HoldRingPainter _buildRingPainter(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color? tone = widget.tone;
    final bool onDark = tone != null && ThemeData.estimateBrightnessForColor(tone) == Brightness.dark;
    return _HoldRingPainter(
      progress: _ring,
      centre: _touch,
      ink: onDark ? Colors.white : cs.onSurface,
      wash: onDark ? Colors.white.withValues(alpha: 0.24) : cs.surface.withValues(alpha: 0.6),
      grow: !context.reduceMotion,
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_entry == null) {
        _pointer = event.pointer;
      } else if (event.pointer != _pointer) {
        _close(animate: false);
      }
    },
    // A tap or a scroll that wins the arena never calls onLongPressCancel, so the ring watches the pointer itself.
    onPointerMove: (event) {
      if (_ringDown != null && (event.position - _ringDown!).distance > kTouchSlop) _releaseRing();
    },
    onPointerUp: (_) => _releaseRing(),
    onPointerCancel: (_) => _releaseRing(),
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
        onLongPressDown: (details) {
          if (_entry != null) return;
          _ringDown = details.globalPosition;
          setState(() => _touch = details.localPosition);
          _ring.forward(from: 0);
        },
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
        // Before the menu opens there is nothing to close. After, only a cancelled pointer gets here.
        onLongPressCancel: _close,
        child: CustomPaint(
          key: const ValueKey<String>('wallpaper-hold-ring'),
          foregroundPainter: _buildRingPainter(context),
          child: Opacity(opacity: _entry == null ? 1 : 0, child: widget.child),
        ),
      ),
    ),
  );
}

/// A light disc under the finger with a 2 pt ring that sweeps once over the long-press timeout.
class _HoldRingPainter extends CustomPainter {
  _HoldRingPainter({
    required this.progress,
    required this.centre,
    required this.ink,
    required this.wash,
    required this.grow,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Offset centre;
  final Color ink;
  final Color wash;
  final bool grow;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    if (t <= 0) return;
    // Fades in over the first 100 ms, so a quick tap or a scroll start barely shows it.
    final double alpha = (t / 0.2).clamp(0.0, 1.0);
    final double radius = grow ? 16 + 8 * PrismCurves.enter.transform(t) : 24;
    canvas.drawCircle(centre, radius, Paint()..color = wash.withValues(alpha: wash.a * alpha));
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * t,
      false,
      Paint()
        ..color = ink.withValues(alpha: ink.a * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HoldRingPainter old) =>
      old.centre != centre || old.ink != ink || old.wash != wash || old.grow != grow || old.progress != progress;
}

class _HoldMotion extends StatefulWidget {
  const _HoldMotion({
    required this.exiting,
    required this.reduceMotion,
    required this.onEntered,
    required this.onDismissed,
    required this.builder,
  });

  final bool exiting;
  final bool reduceMotion;
  final VoidCallback onEntered;
  final VoidCallback onDismissed;
  final Widget Function(double progress) builder;

  @override
  State<_HoldMotion> createState() => _HoldMotionState();
}

class _HoldMotionState extends State<_HoldMotion> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _dismissalScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: PrismDurations.fast, value: widget.reduceMotion ? 1 : 0)
      ..addStatusListener(_onStatus);
    if (widget.exiting) {
      _scheduleDismissal();
    } else if (!widget.reduceMotion) {
      _controller.animateTo(1, curve: PrismCurves.enter);
    }
  }

  @override
  void didUpdateWidget(_HoldMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.exiting && widget.exiting && !widget.reduceMotion) {
      // A gentle ease-out in time. PrismCurves.exit here drops most of the opacity in the first 40 ms, which reads
      // as a snap.
      _controller.animateBack(0, duration: PrismDurations.fast * _controller.value, curve: Curves.easeOut);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !widget.exiting) {
      widget.onEntered();
    } else if (status == AnimationStatus.dismissed && widget.exiting) {
      _scheduleDismissal();
    }
  }

  void _scheduleDismissal() {
    if (_dismissalScheduled) return;
    _dismissalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.exiting) widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _controller, builder: (context, _) => widget.builder(_controller.value));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
