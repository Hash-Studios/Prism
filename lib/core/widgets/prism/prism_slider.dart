import 'package:flutter/material.dart';

/// A Material [Slider] that cannot empty the iOS accessibility tree.
///
/// [Slider] always keeps its value indicator in an [OverlayPortal], and the portal grafts that node into the
/// slider's traversal order. On iOS the engine can then overwrite the accessibility root with an empty node, and
/// VoiceOver sees nothing in the whole app until a relaunch (flutter/flutter#194541). This widget gives the portal a
/// local [Overlay] with no semantics, and describes the slider itself.
class PrismSlider extends StatelessWidget {
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

  String _format(double v) => semanticFormatterCallback?.call(v) ?? '${((v - min) / (max - min) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null && max > min;
    final double step = (max - min) / (divisions ?? 10);
    final double up = (value + step).clamp(min, max);
    final double down = (value - step).clamp(min, max);
    void nudge(double next) {
      onChangeStart?.call(value);
      onChanged!(next);
      onChangeEnd?.call(next);
    }

    return Semantics(
      slider: true,
      enabled: enabled,
      label: label,
      value: _format(value),
      increasedValue: _format(up),
      decreasedValue: _format(down),
      onIncrease: enabled ? () => nudge(up) : null,
      onDecrease: enabled ? () => nudge(down) : null,
      child: ExcludeSemantics(
        child: Overlay.wrap(
          clipBehavior: Clip.none,
          alwaysSizeToContent: true,
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChangeStart: onChangeStart,
            onChangeEnd: onChangeEnd,
            activeColor: activeColor,
            thumbColor: thumbColor,
          ),
        ),
      ),
    );
  }
}
