import 'dart:math' as math;
import 'dart:ui';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// A height a sheet can snap to.
///
/// - [fit]: the height of the content. The sheet floats on an inset above the dimmed screen.
/// - [medium]: about half the screen. For long lists the user is expected to browse.
/// - [large]: full height, just under the status bar. The sheet goes flush with the screen edges and its bottom corners
///   take the screen's own corner radius, so the curve continues into the bezel.
enum PrismSheetDetent { fit, medium, large }

// The fit detent follows the live content height, so a body that grows while open is never cut off.
const SheetOffset _fitOffset = SheetOffset(1);
const SheetOffset _mediumOffset = SheetOffset.proportionalToViewport(0.55);

class _LargeOffset implements SheetOffset {
  const _LargeOffset();

  @override
  double resolve(ViewportLayout metrics) {
    final double height = metrics.viewportSize.height;
    if (height <= 0) return 0;
    return height * ((height - metrics.viewportPadding.top) / height).clamp(0.0, 1.0);
  }
}

// The sheet goes from floating to flush between these shares of the viewport.
const double _flushBegin = 0.6;
const double _flushEnd = 0.9;

/// Where the change from floating to flush starts and ends. Both move up by the keyboard height, so a keyboard that
/// lifts the sheet does not make it flush.
///
/// On a sheet with a fit detent the start is never below the fit height, so a sheet at rest at fit always floats and
/// goes flush only when it is dragged up. Without this, a tall fit sheet rests part way to flush: the inset changes the
/// width, the text wraps again, the height changes, the flush value moves, and the layout never settles.
class _FlushOffset implements SheetOffset {
  const _FlushOffset({required this.end, required this.fromFit});

  final bool end;
  final bool fromFit;

  @override
  double resolve(ViewportLayout metrics) {
    double at(double fraction) => metrics.viewportSize.height * fraction + metrics.viewportPadding.bottom;
    double start = at(_flushBegin);
    if (fromFit) start = math.max(start, _fitOffset.resolve(metrics));
    return end ? math.max(at(_flushEnd), start + 1) : start;
  }
}

SheetOffsetDrivenAnimation _flushAnimation(SheetController controller, {required bool fromFit}) =>
    SheetOffsetDrivenAnimation(
      controller: controller,
      initialValue: 0,
      startOffset: _FlushOffset(end: false, fromFit: fromFit),
      endOffset: _FlushOffset(end: true, fromFit: fromFit),
    );

/// Keeps one padding edge inside the space the sheet viewport has left.
///
/// The sheet subtracts this padding from the viewport when it builds the content constraints. A keyboard, a status
/// bar, or a zero-size parent can ask for more space than the viewport has, and the content height goes negative.
double _insetWithin(double inset, double limit) {
  if (!inset.isFinite || inset <= 0) return 0;
  if (limit.isInfinite) return inset;
  if (!limit.isFinite || limit <= 0) return 0;
  return math.min(inset, limit);
}

/// Opens a Prism bottom sheet. Build the inside with [PrismSheetBody], which draws the handle, the close button,
/// the title and the sticky actions.
///
/// The sheet floats on an inset above a dimmed screen. It opens at [initialDetent] (the first of [detents]) and the
/// user can drag it between [detents]. A scroll view inside scrolls first, and the sheet moves only once the scroll
/// view is at its top.
///
/// Set [barrierDismissible] and [swipeDismissible] to false for a sheet the user must answer.
/// Set [dismissKeyboardOnDrag] on sheets with a text field, so a downward drag closes the keyboard first.
Future<T?> showPrismSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  List<PrismSheetDetent> detents = const <PrismSheetDetent>[PrismSheetDetent.fit, PrismSheetDetent.large],
  PrismSheetDetent? initialDetent,
  bool barrierDismissible = true,
  bool swipeDismissible = true,
  bool dismissKeyboardOnDrag = false,
  bool useRootNavigator = false,
}) {
  assert(detents.isNotEmpty, 'detents must contain at least one entry');
  final bool hasFit = detents.contains(PrismSheetDetent.fit);
  final bool fitOnly = detents.length == 1 && hasFit;
  final SheetController controller = SheetController();
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _PrismSheetRoute<T>(
      sheetController: controller,
      barrierColor: PrismBottomSheet.barrier,
      barrierDismissible: barrierDismissible,
      swipeDismissible: swipeDismissible,
      transitionDuration: context.motion(PrismDurations.sheet),
      transitionCurve: PrismCurves.sheet,
      viewportBuilder: (_, child) => _PrismSheetViewport(controller: controller, fromFit: hasFit, child: child),
      builder: (_) {
        final Widget sheet = _PrismSheet(
          controller: controller,
          detents: detents,
          initialDetent: initialDetent ?? detents.first,
          fitOnly: fitOnly,
          child: Builder(builder: builder),
        );
        if (!dismissKeyboardOnDrag) return sheet;
        return SheetKeyboardDismissible(
          dismissBehavior: const SheetKeyboardDismissBehavior.onDragDown(isContentScrollAware: true),
          child: sheet,
        );
      },
    ),
  );
}

/// How many Prism sheets are on screen, counting one that is still animating away.
int get openPrismSheetCount => _PrismSheetRoute.open;

/// Disposes the sheet controller with the route. The navigator disposes a route only after its subtree is unmounted,
/// so nothing listens to the controller any more.
class _PrismSheetRoute<T> extends ModalSheetRoute<T> {
  _PrismSheetRoute({
    required this.sheetController,
    required super.builder,
    super.viewportBuilder,
    super.barrierColor,
    super.barrierDismissible,
    super.swipeDismissible,
    super.transitionDuration,
    super.transitionCurve,
  });

  final SheetController sheetController;

  static int open = 0;

  @override
  void install() {
    super.install();
    open += 1;
  }

  @override
  void dispose() {
    open -= 1;
    // One frame later, so a notification the controller queued for the end of this frame still finds it alive.
    WidgetsBinding.instance.addPostFrameCallback((_) => sheetController.dispose());
    super.dispose();
  }
}

/// Floats the sheet on its inset, removes the inset as the sheet nears full height, and lifts the sheet above the
/// keyboard.
///
/// The flush animation is made once in [State.initState]. Making it in build would move its listener onto the
/// controller on every keyboard frame, and that throws once the controller is disposed during the pop.
class _PrismSheetViewport extends StatefulWidget {
  const _PrismSheetViewport({required this.controller, required this.fromFit, required this.child});

  final SheetController controller;
  final bool fromFit;
  final Widget child;

  @override
  State<_PrismSheetViewport> createState() => _PrismSheetViewportState();
}

class _PrismSheetViewportState extends State<_PrismSheetViewport> {
  late final SheetOffsetDrivenAnimation _flush = _flushAnimation(widget.controller, fromFit: widget.fromFit);

  @override
  Widget build(BuildContext context) {
    final EdgeInsets view = MediaQuery.viewPaddingOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedBuilder(
      animation: _flush,
      builder: (_, _) {
        final double inset = lerpDouble(PrismBottomSheet.inset, 0, _flush.value)!;
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Clamp here, where the viewport size is known. smooth_sheets subtracts this padding from the
              // viewport to get the content max height, and a negative result fails layout.
              final double top = _insetWithin(view.top + PrismBottomSheet.topInset, constraints.maxHeight);
              final double bottom = _insetWithin(keyboard, constraints.maxHeight - top);
              return SheetViewport(
                padding: EdgeInsets.only(top: top, bottom: bottom),
                child: widget.child,
              );
            },
          ),
        );
      },
    );
  }
}

class _PrismSheet extends StatefulWidget {
  const _PrismSheet({
    required this.controller,
    required this.detents,
    required this.initialDetent,
    required this.fitOnly,
    required this.child,
  });

  final SheetController controller;
  final List<PrismSheetDetent> detents;
  final PrismSheetDetent initialDetent;
  final bool fitOnly;
  final Widget child;

  @override
  State<_PrismSheet> createState() => _PrismSheetState();
}

class _PrismSheetState extends State<_PrismSheet> {
  late final SheetOffsetDrivenAnimation _flush = _flushAnimation(
    widget.controller,
    fromFit: widget.detents.contains(PrismSheetDetent.fit),
  );

  static SheetOffset _offset(PrismSheetDetent detent) => switch (detent) {
    PrismSheetDetent.fit => _fitOffset,
    PrismSheetDetent.medium => _mediumOffset,
    PrismSheetDetent.large => const _LargeOffset(),
  };

  @override
  Widget build(BuildContext context) {
    final List<SheetOffset> snaps = widget.detents.map(_offset).toList();
    return Sheet(
      controller: widget.controller,
      initialOffset: _offset(widget.initialDetent),
      snapGrid: snaps.length == 1 ? SheetSnapGrid.single(snap: snaps.single) : SheetSnapGrid(snaps: snaps),
      // A fit-only sheet must not bounce past its height and show the barrier above it.
      physics: widget.fitOnly ? const ClampingSheetPhysics() : const BouncingSheetPhysics(bounceExtent: 16),
      // The iOS handoff: an inner scroll view scrolls until it reaches its top, then the sheet starts to move.
      scrollConfiguration: widget.fitOnly
          ? SheetScrollConfiguration.disabled
          : const SheetScrollConfiguration(
              scrollSyncMode: SheetScrollHandlingBehavior.onlyFromTop,
              delegateUnhandledOverscrollToChild: true,
            ),
      decoration: SheetDecorationBuilder(
        size: SheetSize.stretch,
        builder: (_, child) => _PrismSheetSurface(flush: _flush, child: child),
      ),
      child: widget.child,
    );
  }
}

/// Paints the sheet fill, its shadow and its corners.
///
/// The bottom radius goes from `screen radius - inset` (floating, so the curve sits concentric inside the bezel) up to
/// the screen radius as the sheet goes flush. Once fully flush it is 0, because the screen's own corners clip the sheet
/// there.
class _PrismSheetSurface extends StatefulWidget {
  const _PrismSheetSurface({required this.flush, required this.child});

  final Animation<double> flush;
  final Widget child;

  @override
  State<_PrismSheetSurface> createState() => _PrismSheetSurfaceState();
}

class _PrismSheetSurfaceState extends State<_PrismSheetSurface> {
  // Merged once: a new merge on each layout tick would move listeners onto a controller that may be disposed.
  late final Listenable _repaint = Listenable.merge(<Listenable>[widget.flush, PrismDeviceCornerRadius.listenable]);

  @override
  Widget build(BuildContext context) {
    final Color surface = Theme.of(context).colorScheme.surfaceContainerLow;
    const Radius top = Radius.circular(PrismBottomSheet.topRadius);
    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) {
        // Read here, not outside the builder: the radius can arrive after the first paint.
        final double screen = PrismDeviceCornerRadius.resolve(context);
        final double floating = lerpDouble(
          screen - PrismBottomSheet.inset,
          screen,
          widget.flush.value,
        )!.clamp(0.0, screen);
        // Square only once fully flush: a sheet at its top height can still float when its content is that tall.
        final Radius bottom = Radius.circular(widget.flush.value >= 1 ? 0 : floating);
        final BorderRadius shape = BorderRadius.only(
          topLeft: top,
          topRight: top,
          bottomLeft: bottom,
          bottomRight: bottom,
        );
        return DecoratedBox(
          decoration: BoxDecoration(color: surface, borderRadius: shape, boxShadow: PrismBottomSheet.shadow),
          child: ClipRRect(borderRadius: shape, child: widget.child),
        );
      },
    );
  }
}
