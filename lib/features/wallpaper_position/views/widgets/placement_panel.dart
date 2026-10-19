import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String _fitLabel(AppLocalizations l10n, PlacementFit fit) => switch (fit) {
    PlacementFit.fill => l10n.wallpaperFitFill,
    PlacementFit.fitBlur => l10n.wallpaperFitBlur,
    PlacementFit.fitColor => l10n.wallpaperFitColour,
  };

  String _targetLabel(AppLocalizations l10n, WallpaperTarget target) => switch (target) {
    WallpaperTarget.home => l10n.wallpaperAutoRotateHomeScreen,
    WallpaperTarget.lock => l10n.wallpaperAutoRotateLockScreen,
    WallpaperTarget.both => l10n.wallpaperHistoryBothScreens,
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
                  for (final PlacementFit fit in PlacementFit.values)
                    ChoiceChip(
                      label: Text(_fitLabel(context.l10n, fit)),
                      selected: placement.fit == fit,
                      onSelected: busy
                          ? null
                          : (_) {
                              PrismHaptics.selection();
                              onFit(fit);
                            },
                    ),
                ],
              ),
              Row(
                children: <Widget>[
                  Text(context.l10n.wallpaperPlacementDim, style: PrismTextStyles.rowTitle(context)),
                  Expanded(
                    child: Slider(
                      value: placement.dim,
                      max: WallpaperPlacement.maxDim,
                      divisions: 12,
                      label: NumberFormat.percentPattern(context.l10n.localeName).format(placement.dim),
                      onChanged: busy ? null : onDim,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      NumberFormat.percentPattern(context.l10n.localeName).format(placement.dim),
                      textAlign: TextAlign.end,
                      style: PrismTextStyles.body(context),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: busy ? null : onReset, child: Text(context.l10n.wallpaperReset)),
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
                          child: Text(_targetLabel(context.l10n, target)),
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
