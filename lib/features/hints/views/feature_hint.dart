import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/features/hints/data/feature_hints.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Wraps the real control of a feature. Each time the control has been on screen for a moment it counts a view, and
/// when [FeatureHints] allows it, a small callout with one line and "Got it" points at the control.
///
/// [enabled] is the surface's own condition, such as "this wall has colour variants". The callout has no scrim, does
/// not take focus, and closes on any tap outside it.
class FeatureHint extends StatefulWidget {
  const FeatureHint({super.key, required this.id, required this.child, this.enabled = true});

  final HintId id;
  final bool enabled;
  final Widget child;

  /// How long the control must stay on screen before it counts as seen. Route transitions finish inside it.
  static const Duration settle = Duration(milliseconds: 700);

  @override
  State<FeatureHint> createState() => _FeatureHintState();
}

class _FeatureHintState extends State<FeatureHint> {
  final GlobalKey _anchor = GlobalKey();
  OverlayEntry? _entry;
  Timer? _timer;
  Timer? _visibilityTimer;
  HintId? _shownId;
  String? _shownUserId;
  Rect? _lastAnchorRect;
  bool _viewed = false;
  bool _routeCurrent = true;

  FeatureHints get _hints => FeatureHints.instance;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(FeatureHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _close(HintDismissMethod.interrupted);
      _viewed = false;
      _timer?.cancel();
    }
    if (!widget.enabled) {
      _timer?.cancel();
      _close(HintDismissMethod.interrupted);
    }
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (!_routeCurrent) _close(HintDismissMethod.interrupted);
  }

  void _schedule() {
    if (_viewed || !widget.enabled || (_timer?.isActive ?? false)) return;
    _timer = Timer(FeatureHint.settle, _check);
  }

  void _check() {
    if (!mounted || !widget.enabled) return;
    _viewed = true;
    if (_hints.view(widget.id, canShow: _canShow())) _show();
  }

  bool _canShow() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return _routeCurrent &&
        openPrismSheetCount == 0 &&
        TickerMode.valuesOf(context).enabled &&
        (route?.animation?.status ?? AnimationStatus.completed) == AnimationStatus.completed &&
        (route?.secondaryAnimation?.status ?? AnimationStatus.dismissed) == AnimationStatus.dismissed &&
        _anchorOnScreen();
  }

  bool _anchorOnScreen() {
    final RenderBox? box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return false;
    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    final MediaQueryData media = MediaQuery.of(context);
    final Rect safe = media.padding.deflateRect(Offset.zero & media.size);
    if (!safe.contains(rect.topLeft) || !safe.contains(rect.bottomRight - const Offset(1, 1))) return false;
    RenderObject child = box;
    while (child.parent != null) {
      final RenderObject parent = child.parent!;
      if (parent is RenderOffstage && parent.offstage) return false;
      final Rect? clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        final Rect visible = MatrixUtils.transformRect(parent.getTransformTo(null), clip);
        if (!visible.contains(rect.topLeft) || !visible.contains(rect.bottomRight - const Offset(1, 1))) return false;
      }
      child = parent;
    }
    return true;
  }

  void _show() {
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      _hints.dismiss(widget.id, HintDismissMethod.interrupted);
      return;
    }
    final String message = kHints[widget.id]!.copy(context.l10n);
    final FocusScopeNode focusScope = FocusScope.of(context);
    _entry = OverlayEntry(
      builder: (_) => Focus(
        parentNode: focusScope,
        canRequestFocus: false,
        skipTraversal: true,
        child: _HintCallout(
          anchor: _anchor,
          overlay: overlay,
          message: message,
          onGotIt: () => _close(HintDismissMethod.gotIt),
          onTapOutside: () => _close(HintDismissMethod.tapOutside),
        ),
      ),
    );
    _shownId = widget.id;
    _shownUserId = _hints.userId;
    overlay.insert(_entry!);
    _visibilityTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _hints.userId != _shownUserId || _hints.active != _shownId || !_canShow()) {
        _close(HintDismissMethod.interrupted);
      } else {
        final RenderBox box = _anchor.currentContext!.findRenderObject()! as RenderBox;
        final Rect rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect != _lastAnchorRect) {
          _lastAnchorRect = rect;
          _entry?.markNeedsBuild();
        }
      }
    });
    _hints.addListener(_onHintsChanged);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context)));
    }
  }

  void _onHintsChanged() {
    if (_hints.active != _shownId) _removeEntry();
  }

  void _afterBuild(VoidCallback action) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => action());
    } else {
      action();
    }
  }

  void _close(HintDismissMethod method) {
    final HintId? id = _shownId;
    if (id == null) return;
    final String? userId = _shownUserId;
    _removeEntry();
    final FeatureHints hints = _hints;
    _afterBuild(() => hints.dismiss(id, method, userId: userId));
  }

  void _removeEntry() {
    _hints.removeListener(_onHintsChanged);
    _visibilityTimer?.cancel();
    final OverlayEntry? entry = _entry;
    _entry = null;
    _shownId = null;
    _shownUserId = null;
    if (entry != null) {
      _afterBuild(() {
        entry.remove();
        entry.dispose();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _close(HintDismissMethod.interrupted);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _anchor, child: widget.child);
}

class _HintCallout extends StatefulWidget {
  const _HintCallout({
    required this.anchor,
    required this.overlay,
    required this.message,
    required this.onGotIt,
    required this.onTapOutside,
  });

  final GlobalKey anchor;
  final OverlayState overlay;
  final String message;
  final VoidCallback onGotIt;
  final VoidCallback onTapOutside;

  @override
  State<_HintCallout> createState() => _HintCalloutState();
}

class _HintCalloutState extends State<_HintCallout> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final CurvedAnimation _curve = CurvedAnimation(parent: _controller, curve: PrismCurves.enter);
  final ValueNotifier<bool> _below = ValueNotifier<bool>(true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = context.motion(PrismDurations.base);
    if (_controller.duration == Duration.zero) {
      _controller.value = 1;
    } else if (_controller.status == AnimationStatus.dismissed) {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _below.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RenderBox? anchor = widget.anchor.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlay = widget.overlay.context.findRenderObject() as RenderBox?;
    if (anchor == null || overlay == null || !anchor.attached || !anchor.hasSize || !overlay.hasSize) {
      return const SizedBox.shrink();
    }
    final Rect target = anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle text = PrismTextStyles.caption(context).copyWith(color: cs.onInverseSurface);
    final Widget bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x29000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: PrismSpace.sm, end: PrismSpace.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
                child: Text(widget.message, style: text),
              ),
            ),
            Semantics(
              container: true,
              button: true,
              child: FocusableActionDetector(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                },
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      widget.onGotIt();
                      return null;
                    },
                  ),
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onGotIt,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          context.l10n.hintGotIt,
                          style: text.copyWith(color: cs.inversePrimary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // The overlay sits outside any Material, so give the text a theme style.
    return Material(
      type: MaterialType.transparency,
      child: CustomMultiChildLayout(
        delegate: _CalloutLayout(target: target, below: _below, padding: MediaQuery.paddingOf(context)),
        children: <Widget>[
          LayoutId(
            id: _CalloutPart.arrow,
            child: FadeTransition(
              opacity: _curve,
              child: CustomPaint(
                size: const Size(_arrowWidth, _arrowHeight),
                painter: _ArrowPainter(color: cs.inverseSurface, up: _below),
              ),
            ),
          ),
          LayoutId(
            id: _CalloutPart.bubble,
            child: TapRegion(
              onTapOutside: (_) => widget.onTapOutside(),
              child: Semantics(
                container: true,
                liveRegion: defaultTargetPlatform != TargetPlatform.iOS,
                child: FadeTransition(
                  opacity: _curve,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1).animate(_curve), child: bubble),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _arrowWidth = 14;
const double _arrowHeight = 7;
const double _gap = 4;
const double _maxWidth = 320;

enum _CalloutPart { arrow, bubble }

class _CalloutLayout extends MultiChildLayoutDelegate {
  _CalloutLayout({required this.target, required this.below, required this.padding});

  /// Set during layout: true when the bubble sits below the control. The arrow reads it when it paints.

  final Rect target;
  final ValueNotifier<bool> below;
  final EdgeInsets padding;

  @override
  void performLayout(Size size) {
    final double maxWidth = math.max(0, math.min(_maxWidth, size.width - 2 * PrismSpace.page));
    final Size bubble = layoutChild(_CalloutPart.bubble, BoxConstraints(maxWidth: maxWidth));
    layoutChild(_CalloutPart.arrow, BoxConstraints.tight(const Size(_arrowWidth, _arrowHeight)));
    final double left = (target.center.dx - bubble.width / 2).clamp(
      PrismSpace.page,
      math.max(PrismSpace.page, size.width - PrismSpace.page - bubble.width),
    );
    final double arrowLeft = (target.center.dx - _arrowWidth / 2).clamp(
      left + PrismRadius.sm,
      math.max(left + PrismRadius.sm, left + bubble.width - PrismRadius.sm - _arrowWidth),
    );
    // Below the control when the bubble fits there, so it does not cover the actions above a bottom control.
    final double room = _gap + _arrowHeight + bubble.height;
    below.value = target.bottom + room <= size.height - padding.bottom || target.top - room < padding.top;
    final double arrowTop = below.value ? target.bottom + _gap : target.top - _gap - _arrowHeight;
    final double bubbleTop = below.value ? arrowTop + _arrowHeight : arrowTop - bubble.height;
    positionChild(_CalloutPart.arrow, Offset(arrowLeft, arrowTop));
    positionChild(
      _CalloutPart.bubble,
      Offset(left, bubbleTop.clamp(padding.top, math.max(padding.top, size.height - padding.bottom - bubble.height))),
    );
  }

  @override
  bool shouldRelayout(_CalloutLayout oldDelegate) => target != oldDelegate.target || padding != oldDelegate.padding;
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color, required this.up}) : super(repaint: up);

  final Color color;
  final ValueListenable<bool> up;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = up.value
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => color != oldDelegate.color || up != oldDelegate.up;
}
