import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/features/hints/data/feature_hints.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
    if (!widget.enabled) _close(HintDismissMethod.interrupted);
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
    if (_hints.view(widget.id, canShow: _routeCurrent && _anchorOnScreen())) _show();
  }

  bool _anchorOnScreen() {
    final RenderBox? box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return false;
    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    final MediaQueryData media = MediaQuery.of(context);
    final Rect safe = media.padding.deflateRect(Offset.zero & media.size);
    return safe.contains(rect.topLeft) && safe.contains(rect.bottomRight - const Offset(1, 1));
  }

  void _show() {
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      _hints.dismiss(widget.id, HintDismissMethod.interrupted);
      return;
    }
    final String message = kHints[widget.id]!.copy(context.l10n);
    _entry = OverlayEntry(
      builder: (_) => _HintCallout(
        anchor: _anchor,
        overlay: overlay,
        message: message,
        onGotIt: () => _close(HintDismissMethod.gotIt),
        onTapOutside: () => _close(HintDismissMethod.tapOutside),
      ),
    );
    overlay.insert(_entry!);
    _hints.addListener(_onHintsChanged);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context)));
    }
  }

  void _onHintsChanged() {
    if (_hints.active != widget.id) _removeEntry();
  }

  void _close(HintDismissMethod method) {
    if (_entry == null) return;
    _removeEntry();
    _hints.dismiss(widget.id, method);
  }

  void _removeEntry() {
    _hints.removeListener(_onHintsChanged);
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
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
    final bool below = target.center.dy < overlay.size.height / 2;
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
              button: true,
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
          ],
        ),
      ),
    );
    return CustomMultiChildLayout(
      delegate: _CalloutLayout(target: target, below: below, padding: MediaQuery.paddingOf(context)),
      children: <Widget>[
        LayoutId(
          id: _CalloutPart.arrow,
          child: FadeTransition(
            opacity: _curve,
            child: CustomPaint(
              size: const Size(_arrowWidth, _arrowHeight),
              painter: _ArrowPainter(color: cs.inverseSurface, up: below),
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
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1).animate(_curve),
                  alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
                  child: bubble,
                ),
              ),
            ),
          ),
        ),
      ],
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

  final Rect target;
  final bool below;
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
    final double arrowTop = below ? target.bottom + _gap : target.top - _gap - _arrowHeight;
    final double bubbleTop = below ? arrowTop + _arrowHeight : arrowTop - bubble.height;
    positionChild(_CalloutPart.arrow, Offset(arrowLeft, arrowTop));
    positionChild(
      _CalloutPart.bubble,
      Offset(left, bubbleTop.clamp(padding.top, math.max(padding.top, size.height - padding.bottom - bubble.height))),
    );
  }

  @override
  bool shouldRelayout(_CalloutLayout oldDelegate) =>
      target != oldDelegate.target || below != oldDelegate.below || padding != oldDelegate.padding;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = up
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
