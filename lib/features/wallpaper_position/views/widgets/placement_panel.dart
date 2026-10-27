import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Fit choice, dim slider, reset, and Done under the preview.
class PlacementPanel extends StatelessWidget {
  const PlacementPanel({
    super.key,
    required this.placement,
    required this.busy,
    required this.onFit,
    required this.onDim,
    required this.onReset,
    required this.onDone,
    this.onSystemEditor,
  });

  final WallpaperPlacement placement;
  final bool busy;
  final ValueChanged<PlacementFit> onFit;
  final ValueChanged<double> onDim;
  final VoidCallback onReset;
  final VoidCallback onDone;

  /// Opens the Android system editor. Null hides the button.
  final VoidCallback? onSystemEditor;

  String _fitLabel(AppLocalizations l10n, PlacementFit fit) => switch (fit) {
    PlacementFit.fill => l10n.wallpaperFitFill,
    PlacementFit.fitBlur => l10n.wallpaperFitBlur,
    PlacementFit.fitColor => l10n.wallpaperFitColour,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
              if (onSystemEditor != null) ...<Widget>[
                PrismButton(
                  label: context.l10n.setScreenOpenSystemEditor,
                  variant: PrismButtonVariant.tonal,
                  icon: Icons.crop_rounded,
                  onPressed: busy ? null : onSystemEditor,
                  expand: true,
                ),
                const SizedBox(height: PrismSpace.xs),
              ],
              PrismButton(label: context.l10n.coreDone, loading: busy, onPressed: onDone, expand: true),
            ],
          ),
        ),
      ),
    );
  }
}
