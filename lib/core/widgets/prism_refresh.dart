import 'dart:math' as math;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:flutter/material.dart';

/// Pull to refresh with the Prism mark. Use it in place of [RefreshIndicator]; it takes the same main parameters.
///
/// On iOS and macOS (bouncing scroll) the mark draws itself under the top edge as the user pulls: a selection haptic
/// at each step, an impact at the trigger. Released past the trigger, the content holds a gap with the looping mark
/// until [onRefresh] completes, then closes it. On Android it is a [RefreshIndicator] in the page colours.
class PrismRefresh extends StatefulWidget {
  const PrismRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.edgeOffset = 0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Widget child;
  final RefreshCallback onRefresh;

  /// Distance from the top of [child] to where the visible content starts, for content that scrolls under a header.
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;

  /// Pull distance that starts a refresh on iOS.
  static const double triggerDistance = 80;

  /// Gap the content keeps above it while an iOS refresh runs.
  static const double holdExtent = 56;

  @override
  State<PrismRefresh> createState() => _PrismRefreshState();
}

class _PrismRefreshState extends State<PrismRefresh> with SingleTickerProviderStateMixin {
  static const double _loaderSize = 28;

  /// How far the content is pulled past its top, in pixels.
  final ValueNotifier<double> _pull = ValueNotifier<double>(0);

  /// 1 while a refresh holds the gap open, animates to 0 when it ends.
  late final AnimationController _hold = AnimationController(vsync: this);

  bool _refreshing = false;
  bool _armed = false;
  int _step = 0;

  @override
  void dispose() {
    _pull.dispose();
    _hold.dispose();
    super.dispose();
  }

  Future<void> _androidRefresh() {
    PrismHaptics.impact();
    return widget.onRefresh();
  }

  bool _onScroll(ScrollNotification n) {
    if (!widget.notificationPredicate(n) || n.metrics.axis != Axis.vertical) return false;
    _pull.value = math.max(0, n.metrics.minScrollExtent - n.metrics.pixels);
    if (_refreshing) return false;
    final bool dragging = n is ScrollUpdateNotification && n.dragDetails != null;
    if (dragging) {
      final int step = (_pull.value / PrismRefresh.triggerDistance * 3).floor().clamp(0, 3);
      if (step > _step) step == 3 ? PrismHaptics.impact() : PrismHaptics.selection();
      _step = step;
      _armed = step == 3;
    } else if (_armed && (n is ScrollUpdateNotification || n is ScrollEndNotification)) {
      _start();
    } else if (_pull.value == 0) {
      _step = 0;
    }
    return false;
  }

  Future<void> _start() async {
    _armed = false;
    _step = 0;
    _hold.value = 1;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        if (context.reduceMotion) {
          _hold.value = 0;
        } else {
          await _hold.animateTo(0, duration: PrismDurations.base, curve: PrismCurves.exit);
        }
        if (mounted) setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (theme.platform != TargetPlatform.iOS && theme.platform != TargetPlatform.macOS) {
      return RefreshIndicator(
        onRefresh: _androidRefresh,
        edgeOffset: widget.edgeOffset,
        notificationPredicate: widget.notificationPredicate,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        child: widget.child,
      );
    }
    final Listenable motion = Listenable.merge(<Listenable>[_pull, _hold]);
    // While refreshing, the content keeps at least the hold gap above it. The bounce back fills the rest.
    double shift() => _refreshing ? math.max(0, PrismRefresh.holdExtent * _hold.value - _pull.value) : 0;
    return Stack(
      children: <Widget>[
        AnimatedBuilder(
          animation: motion,
          builder: (context, child) => Transform.translate(offset: Offset(0, shift()), child: child),
          child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
        ),
        Positioned(
          top: widget.edgeOffset,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, _) {
                final double gap = _pull.value + shift();
                final double opacity = _refreshing ? _hold.value : ((gap - 8) / 24).clamp(0, 1);
                if (opacity == 0) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: math.max(0, (gap - _loaderSize) / 2)),
                  child: Opacity(
                    opacity: opacity,
                    child: Center(
                      child: _refreshing
                          ? Semantics(
                              label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
                              child: const PrismLoader(),
                            )
                          : PrismLoader.progress((gap / PrismRefresh.triggerDistance).clamp(0, 1)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
