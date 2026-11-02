import 'package:flutter/material.dart';

/// A Material [Slider] that cannot empty the iOS accessibility tree.
///
/// [Slider] always keeps its value indicator in an [OverlayPortal], and the portal grafts that node into the
/// slider's traversal order. On iOS the engine can then overwrite the accessibility root with an empty node, and
/// VoiceOver sees nothing in the whole app until a relaunch (flutter/flutter#194541). This widget gives the portal a
/// local [Overlay] with no semantics, and describes the slider itself.
class PrismSlider extends StatefulWidget {
  const PrismSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.semanticFormatterCallback,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.thumbColor,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final SemanticFormatterCallback? semanticFormatterCallback;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? thumbColor;

  @override
  State<PrismSlider> createState() => _PrismSliderState();
}

class _PrismSliderState extends State<PrismSlider> {
  late final FocusNode _focusNode = FocusNode()..addListener(_handleFocusChange);

  void _handleFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  double _normalized(double value) {
    if (widget.max == widget.min) return 0;
    final double normalized = (value - widget.min) / (widget.max - widget.min);
    if (widget.divisions case final int divisions?) {
      return (normalized * divisions).round() / divisions;
    }
    return normalized;
  }

  double _value(double normalized) => normalized * (widget.max - widget.min) + widget.min;

  String _format(double normalized) =>
      widget.semanticFormatterCallback?.call(_value(normalized)) ?? '${(normalized * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onChanged != null && widget.max > widget.min;
    final TargetPlatform platform = Theme.of(context).platform;
    final double normalized = _normalized(widget.value);
    final double step = switch (widget.divisions) {
      final int divisions? => 1 / divisions,
      null => switch (platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 0.1,
        _ => 0.05,
      },
    };
    final double up = (normalized + step).clamp(0.0, 1.0);
    final double down = (normalized - step).clamp(0.0, 1.0);
    void nudge(double next) {
      final double currentValue = _value(normalized);
      final double nextValue = _value(next);
      widget.onChangeStart?.call(currentValue);
      if (nextValue != widget.value) widget.onChanged!(nextValue);
      widget.onChangeEnd?.call(nextValue);
    }

    return Semantics(
      slider: true,
      enabled: enabled,
      focusable: enabled,
      focused: _focusNode.hasFocus,
      onFocus: enabled ? _focusNode.requestFocus : null,
      onDidGainAccessibilityFocus: enabled && platform == TargetPlatform.windows ? _focusNode.requestFocus : null,
      label: widget.label,
      value: _format(normalized),
      increasedValue: _format(up),
      decreasedValue: _format(down),
      onIncrease: enabled ? () => nudge(up) : null,
      onDecrease: enabled ? () => nudge(down) : null,
      child: ExcludeSemantics(
        child: Overlay.wrap(
          clipBehavior: Clip.none,
          alwaysSizeToContent: true,
          child: Slider(
            value: widget.value,
            onChanged: widget.onChanged,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: widget.label,
            onChangeStart: widget.onChangeStart,
            onChangeEnd: widget.onChangeEnd,
            activeColor: widget.activeColor,
            thumbColor: widget.thumbColor,
            focusNode: _focusNode,
          ),
        ),
      ),
    );
  }
}
