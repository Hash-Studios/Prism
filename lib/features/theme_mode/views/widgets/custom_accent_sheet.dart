import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/theme_mode/domain/custom_accent.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the custom accent picker. Returns the picked colour, or null when dismissed.
Future<Color?> showCustomAccentSheet(BuildContext context, {required Color initial, required Color surface}) {
  return showPrismSheet<Color>(
    context,
    dismissKeyboardOnDrag: true,
    builder: (_) => _CustomAccentSheet(initial: initial, surface: surface),
  );
}

String _hexOf(HSLColor color) => '#${color.toColor().rgbHex.toUpperCase()}';

class _CustomAccentSheet extends StatefulWidget {
  const _CustomAccentSheet({required this.initial, required this.surface});

  final Color initial;

  /// The page background the accent must stay readable on.
  final Color surface;

  @override
  State<_CustomAccentSheet> createState() => _CustomAccentSheetState();
}

class _CustomAccentSheetState extends State<_CustomAccentSheet> {
  late HSLColor _value = HSLColor.fromColor(widget.initial);
  late final TextEditingController _hex = TextEditingController(text: _hexOf(_value));
  final FocusNode _hexFocus = FocusNode();

  @override
  void dispose() {
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _onHexChanged(String text) {
    final Color? parsed = parseAccentHex(text);
    setState(() {
      if (parsed != null) _value = HSLColor.fromColor(parsed);
    });
  }

  void _onSliderChanged(HSLColor next) {
    setState(() {
      _value = next;
      if (!_hexFocus.hasFocus) _hex.text = _hexOf(_value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = _value.toColor();
    final bool invalid = parseAccentHex(_hex.text) == null;
    final bool lowContrast = !invalid && !accentReadsOn(color, widget.surface);
    final bool canApply = !invalid && !lowContrast;
    final TextStyle statusStyle = PrismTextStyles.body(context).copyWith(color: cs.error);
    final String? statusText = invalid
        ? context.l10n.coreCustomAccentInvalidHex
        : lowContrast
        ? context.l10n.coreCustomAccentLowContrast
        : null;

    return PrismSheetBody(
      title: context.l10n.coreCustomAccent,
      actions: <Widget>[
        PrismButton(
          label: context.l10n.coreCustomAccentApply,
          expand: true,
          onPressed: canApply
              ? () {
                  PrismHaptics.selection();
                  Navigator.pop(context, color);
                }
              : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                ),
              ),
              const SizedBox(width: PrismSpace.md),
              Expanded(
                child: PrismTextField(
                  controller: _hex,
                  focusNode: _hexFocus,
                  label: context.l10n.coreCustomAccentHex,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onChanged: _onHexChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.lg),
          _ChannelSlider(
            label: context.l10n.coreCustomAccentHue,
            color: color,
            value: _value.hue,
            max: 360,
            formatValue: (value) => '${value.round()}°',
            onChangeStart: () => _hexFocus.unfocus(),
            onChanged: (value) => _onSliderChanged(_value.withHue(value)),
          ),
          const SizedBox(height: PrismSpace.md),
          _ChannelSlider(
            label: context.l10n.coreCustomAccentSaturation,
            color: color,
            value: _value.saturation,
            max: 1,
            formatValue: (value) => '${(value * 100).round()}%',
            onChangeStart: () => _hexFocus.unfocus(),
            onChanged: (value) => _onSliderChanged(_value.withSaturation(value)),
          ),
          const SizedBox(height: PrismSpace.md),
          _ChannelSlider(
            label: context.l10n.coreCustomAccentLightness,
            color: color,
            value: _value.lightness,
            max: 1,
            formatValue: (value) => '${(value * 100).round()}%',
            onChangeStart: () => _hexFocus.unfocus(),
            onChanged: (value) => _onSliderChanged(_value.withLightness(value)),
          ),
          if (statusText != null) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (lowContrast) ...<Widget>[
                    Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
                    const SizedBox(width: PrismSpace.xs),
                  ],
                  Expanded(child: Text(statusText, style: statusStyle)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.max,
    required this.formatValue,
    required this.onChangeStart,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final double value;
  final double max;
  final String Function(double value) formatValue;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(child: Text(label, style: PrismTextStyles.rowTitle(context))),
        Semantics(
          label: label,
          child: Slider(
            value: value,
            max: max,
            activeColor: color,
            thumbColor: color,
            semanticFormatterCallback: formatValue,
            onChangeStart: (_) => onChangeStart(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
