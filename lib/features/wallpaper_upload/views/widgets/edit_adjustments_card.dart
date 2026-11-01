import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism/prism_slider.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The crop shapes the editor offers. [ratio] is width over height.
enum EditCropRatio {
  r9x18(1 / 2, '9:18'),
  r9x16(9 / 16, '9:16'),
  r9x21(9 / 21, '9:21'),
  r9x195(9 / 19.5, '9:19.5');

  const EditCropRatio(this.ratio, this.label);

  final double ratio;
  final String label;
}

/// Crop shape, flip and rotate, then saturation, brightness and contrast, in one card.
class EditAdjustmentsCard extends StatelessWidget {
  const EditAdjustmentsCard({
    super.key,
    required this.cropRatio,
    required this.onCropRatio,
    required this.onFlip,
    required this.onRotate,
    required this.saturation,
    required this.brightness,
    required this.contrast,
    required this.onSaturation,
    required this.onBrightness,
    required this.onContrast,
  });

  final EditCropRatio cropRatio;
  final ValueChanged<EditCropRatio> onCropRatio;
  final VoidCallback onFlip;

  /// Called with true to rotate right, false to rotate left.
  final ValueChanged<bool> onRotate;
  final double saturation;
  final double brightness;
  final double contrast;
  final ValueChanged<double> onSaturation;
  final ValueChanged<double> onBrightness;
  final ValueChanged<double> onContrast;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              for (final EditCropRatio ratio in EditCropRatio.values)
                PrismChip(label: ratio.label, selected: ratio == cropRatio, onTap: () => onCropRatio(ratio)),
            ],
          ),
          const SizedBox(height: PrismSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              PrismIconButton(icon: Icons.flip_rounded, tooltip: context.l10n.wallpaperUploadFlip, onPressed: onFlip),
              PrismIconButton(
                icon: Icons.rotate_left_rounded,
                tooltip: context.l10n.wallpaperUploadRotateLeft,
                onPressed: () => onRotate(false),
              ),
              PrismIconButton(
                icon: Icons.rotate_right_rounded,
                tooltip: context.l10n.wallpaperUploadRotateRight,
                onPressed: () => onRotate(true),
              ),
            ],
          ),
          Divider(height: PrismSpace.lg, color: cs.onSurface.withValues(alpha: 0.08)),
          _SliderRow(
            label: context.l10n.wallpaperUploadSaturation,
            value: saturation,
            min: 0,
            max: 2,
            onChanged: onSaturation,
          ),
          _SliderRow(
            label: context.l10n.wallpaperUploadBrightness,
            value: brightness,
            min: -1,
            max: 1,
            onChanged: onBrightness,
          ),
          _SliderRow(
            label: context.l10n.wallpaperUploadContrast,
            value: contrast,
            min: 0,
            max: 4,
            onChanged: onContrast,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final NumberFormat valueFormat = NumberFormat('0.00', context.l10n.localeName);
    return Padding(
      padding: const EdgeInsets.only(top: PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: PrismTextStyles.rowTitle(context))),
              Text(valueFormat.format(value), style: PrismTextStyles.caption(context)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              showValueIndicator: ShowValueIndicator.never,
              trackHeight: 4,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
              thumbColor: cs.primary,
              overlayColor: cs.primary.withValues(alpha: 0.12),
            ),
            child: SizedBox(
              height: 32,
              child: PrismSlider(
                label: '$label ${valueFormat.format(value)}',
                semanticFormatterCallback: (double value) => valueFormat.format(value),
                onChanged: onChanged,
                onChangeEnd: (_) => PrismHaptics.selection(),
                divisions: 50,
                value: value,
                min: min,
                max: max,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
