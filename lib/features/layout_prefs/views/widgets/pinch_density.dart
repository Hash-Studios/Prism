import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:flutter/widgets.dart';

/// A pinch over [child] changes the grid density one step: spread for bigger tiles, pinch in for smaller ones.
///
/// It reads raw pointers and never joins the gesture arena, so one-finger scrolls and taps reach [child] as before.
/// [controller] keeps about the same wallpaper on screen after the grid relayouts.
class PinchDensity extends StatefulWidget {
  const PinchDensity({super.key, required this.store, required this.child, this.controller});

  /// Null turns the gesture off.
  final LayoutPrefsStore? store;
  final ScrollController? controller;
  final Widget child;

  /// Scale past which a pinch counts. A small, accidental two-finger touch does nothing.
  static const double threshold = 1.3;

  @override
  State<PinchDensity> createState() => _PinchDensityState();
}

class _PinchDensityState extends State<PinchDensity> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _startSpan;

  double get _span => (_pointers.values.first - _pointers.values.last).distance;

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    _startSpan = _pointers.length == 2 ? _span : null;
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final double? start = _startSpan;
    if (_pointers.length != 2 || start == null || start <= 0) return;
    final double scale = _span / start;
    if (scale >= PinchDensity.threshold) {
      _step(widget.store!.value.density.larger);
    } else if (scale <= 1 / PinchDensity.threshold) {
      _step(widget.store!.value.density.smaller);
    }
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    _startSpan = null;
  }

  /// One step per pinch: the gesture ends its turn here until a finger lifts.
  void _step(WallGridDensity? next) {
    _startSpan = null;
    final LayoutPrefsStore? store = widget.store;
    if (next == null || store == null) return;
    final WallGridDensity previous = store.value.density;
    final double width = MediaQuery.sizeOf(context).width;
    PrismHaptics.selection();
    store.update(store.value.copyWith(density: next));
    analytics.track(LayoutDensityChangedEvent(density: next, source: LayoutChangeSourceValue.pinch));
    _keepPlace(previous.columnsFor(width), next.columnsFor(width));
  }

  // ponytail: scales the offset by tiles per pixel, so headers and mood rows make it approximate. Anchor on the
  // first visible tile if users notice the drift.
  void _keepPlace(int fromColumns, int toColumns) {
    final ScrollController? controller = widget.controller;
    if (controller == null || !controller.hasClients || fromColumns == toColumns) return;
    final double offset = controller.offset * (fromColumns / toColumns) * (fromColumns / toColumns);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      final ScrollPosition position = controller.position;
      controller.jumpTo(offset.clamp(position.minScrollExtent, position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) => widget.store == null
      ? widget.child
      : Listener(
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: widget.child,
        );
}
