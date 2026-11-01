import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../config/bottom_bar_motion.dart';

/// Wraps [child] in the transition selected by [motion].
///
/// Drives off [animation] (0 = hidden, 1 = shown). When
/// [BottomBarMotion.transitionBuilder] is non-null it is used directly;
/// otherwise [BottomBarMotion.transition] dispatches to a built-in.
class VisibilityAnimator extends StatelessWidget {
  const VisibilityAnimator({
    super.key,
    required this.animation,
    required this.isVisible,
    required this.motion,
    required this.child,
    this.slideTargetResolver,
  });

  final Animation<double> animation;
  final bool isVisible;
  final BottomBarMotion motion;
  final Widget child;
  final RenderBox? Function()? slideTargetResolver;

  @override
  Widget build(BuildContext context) {
    final builder = motion.transitionBuilder;
    if (builder != null) {
      return _wrapInteraction(
        AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => builder(context, animation, child!),
        ),
      );
    }
    final clamped = _ClampedAnimation(animation, max: 1);

    switch (motion.transition) {
      case BottomBarTransition.slide:
        return _wrapInteraction(
          AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) => EdgeSlide(
              start: motion.slideStart,
              end: motion.slideEnd,
              progress: animation.value,
              targetResolver: slideTargetResolver,
              child: child,
            ),
          ),
        );
      case BottomBarTransition.fade:
        return _wrapInteraction(FadeTransition(opacity: clamped, child: child));
      case BottomBarTransition.scale:
        return _wrapInteraction(
          ScaleTransition(scale: _ClampedAnimation(animation), child: child),
        );
      case BottomBarTransition.slideAndFade:
        return _wrapInteraction(
          FadeTransition(
            opacity: clamped,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: motion.slideStart,
                end: motion.slideEnd,
              ).animate(animation),
              child: child,
            ),
          ),
        );
    }
  }

  Widget _wrapInteraction(Widget child) {
    return ExcludeFocus(
      excluding: !isVisible,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: ExcludeSemantics(excluding: !isVisible, child: child),
      ),
    );
  }
}

/// Clamps [parent] to `[0, max]` so spring overshoot never feeds a negative
/// scale or an out-of-range opacity.
class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent, {this.max = double.infinity});

  @override
  final Animation<double> parent;
  final double max;

  @override
  double get value => parent.value.clamp(0, max);
}

/// Slides [child] from [start] (hidden, at [progress] 0) to [end] (shown, at
/// [progress] 1), in multiples of the resolved target's size.
///
/// When [targetResolver] is supplied, it identifies the visual bar inside the
/// larger layout child. This keeps its layout footprint stable while the
/// entire subtree is translated for paint and hit testing.
class EdgeSlide extends SingleChildRenderObjectWidget {
  const EdgeSlide({
    super.key,
    required this.start,
    required this.end,
    required this.progress,
    this.targetResolver,
    super.child,
  });

  final Offset start;
  final Offset end;
  final double progress;

  /// Resolves the box whose size and bounds define this slide, if distinct
  /// from the layout child.
  final RenderBox? Function()? targetResolver;

  @override
  RenderEdgeSlide createRenderObject(BuildContext context) {
    return RenderEdgeSlide(
      start: start,
      end: end,
      progress: progress,
      targetResolver: targetResolver,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderEdgeSlide renderObject) {
    renderObject
      ..start = start
      ..end = end
      ..progress = progress
      ..targetResolver = targetResolver;
  }
}

class RenderEdgeSlide extends RenderProxyBox {
  RenderEdgeSlide({
    required this._start,
    required this._end,
    required this._progress,
    required this._targetResolver,
  });

  Offset _start;
  set start(Offset value) {
    if (value == _start) return;
    _start = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Offset _end;
  set end(Offset value) {
    if (value == _end) return;
    _end = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  double _progress;
  set progress(double value) {
    if (value == _progress) return;
    _progress = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  RenderBox? Function()? _targetResolver;
  set targetResolver(RenderBox? Function()? value) {
    if (value == _targetResolver) return;
    _targetResolver = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Offset get translation {
    final targetRect = _targetRect;
    final hidden =
        Offset(_start.dx * targetRect.width, _start.dy * targetRect.height) +
        _gapToHostEdge(_start, targetRect);
    final shown = Offset(
      _end.dx * targetRect.width,
      _end.dy * targetRect.height,
    );
    return hidden + (shown - hidden) * _progress;
  }

  Rect get _targetRect {
    final currentChild = child;
    final target = _targetResolver?.call();
    if (currentChild == null ||
        target == null ||
        !currentChild.attached ||
        !target.attached) {
      return Offset.zero & size;
    }
    return MatrixUtils.transformRect(
      target.getTransformTo(currentChild),
      Offset.zero & target.size,
    );
  }

  // Distance from the target bounds to the nearest host Stack edge along the
  // axes [direction] moves on.
  Offset _gapToHostEdge(Offset direction, Rect targetRect) {
    if (direction == Offset.zero) return Offset.zero;
    var host = parent;
    while (host != null && host is! RenderStack) {
      host = host.parent;
    }
    if (host is! RenderStack || !host.hasSize) return Offset.zero;
    final rect = MatrixUtils.transformRect(getTransformTo(host), targetRect);
    return Offset(
      direction.dx > 0
          ? host.size.width - rect.right
          : (direction.dx < 0 ? -rect.left : 0),
      direction.dy > 0
          ? host.size.height - rect.bottom
          : (direction.dy < 0 ? -rect.top : 0),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The child paints outside this box while sliding; test it there.
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: translation,
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset + translation);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final t = translation;
    transform.translateByDouble(t.dx, t.dy, 0, 1);
  }
}
