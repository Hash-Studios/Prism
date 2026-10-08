import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Fit choice, dim slider, reset and the set buttons under the preview.
class PlacementPanel extends StatelessWidget {
  const PlacementPanel({
    super.key,
    required this.placement,
    required this.busy,
    required this.targets,
    required this.onFit,
    required this.onDim,
    required this.onReset,
    required this.onSet,
  });

  final WallpaperPlacement placement;
  final bool busy;

  /// The screens this device can set.
  final List<WallpaperTarget> targets;
  final ValueChanged<PlacementFit> onFit;
  final ValueChanged<double> onDim;
  final VoidCallback onReset;
  final ValueChanged<WallpaperTarget> onSet;

  static const Map<PlacementFit, String> _fitLabels = <PlacementFit, String>{
    PlacementFit.fill: 'Fill',
    PlacementFit.fitBlur: 'Fit with blur',
    PlacementFit.fitColor: 'Fit with colour',
  };

  static String _targetLabel(WallpaperTarget target) => switch (target) {
    WallpaperTarget.home => 'Home screen',
    WallpaperTarget.lock => 'Lock screen',
    WallpaperTarget.both => 'Both',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Material(
      color: theme.primaryColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final MapEntry<PlacementFit, String> entry in _fitLabels.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: placement.fit == entry.key,
                      onSelected: busy
                          ? null
                          : (_) {
                              PrismHaptics.selection();
                              onFit(entry.key);
                            },
                    ),
                ],
              ),
              Row(
                children: <Widget>[
                  Text('Dim', style: PrismTextStyles.rowTitle(context)),
                  Expanded(
                    child: Slider(
                      value: placement.dim,
                      max: WallpaperPlacement.maxDim,
                      divisions: 12,
                      label: '${(placement.dim * 100).round()}%',
                      onChanged: busy ? null : onDim,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(placement.dim * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: PrismTextStyles.body(context),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: busy ? null : onReset, child: const Text('Reset')),
              ),
              if (busy) ...<Widget>[
                LinearProgressIndicator(color: scheme.error, backgroundColor: scheme.error.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
              ],
              Row(
                children: <Widget>[
                  for (final WallpaperTarget target in targets)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: busy
                              ? null
                              : () {
                                  PrismHaptics.tap();
                                  onSet(target);
                                },
                          child: Text(_targetLabel(target)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
