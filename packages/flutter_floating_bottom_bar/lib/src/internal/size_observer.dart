import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports child size changes after layout without polling.
class SizeObserver extends SingleChildRenderObjectWidget {
  const SizeObserver({
    required this.onSizeChanged,
    required super.child,
    super.key,
  });

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeObserver(onSizeChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderSizeObserver).onSizeChanged = onSizeChanged;
  }
}

class _RenderSizeObserver extends RenderProxyBox {
  _RenderSizeObserver(this._onSizeChanged);

  ValueChanged<Size> _onSizeChanged;
  Size? _lastReportedSize;
  Size? _pendingSize;
  bool _callbackScheduled = false;

  set onSizeChanged(ValueChanged<Size> value) {
    _onSizeChanged = value;
  }

  @override
  void performLayout() {
    super.performLayout();

    final nextSize = size;
    if (_lastReportedSize == nextSize) {
      _pendingSize = null;
      return;
    }

    _pendingSize = nextSize;
    if (_callbackScheduled) return;

    _callbackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _callbackScheduled = false;

      final pendingSize = _pendingSize;
      _pendingSize = null;

      if (!attached ||
          pendingSize == null ||
          pendingSize == _lastReportedSize) {
        return;
      }

      _lastReportedSize = pendingSize;
      _onSizeChanged(pendingSize);
    });
  }
}
