import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_pickers.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Shows every style as a large preview of the same scene. Resolves with the tapped style, or null when dismissed.
Future<AiStylePreset?> showAiStyleSheet(BuildContext context, {required AiStylePreset selected}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return showPrismSheet<AiStylePreset>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.large],
    builder: (BuildContext sheetContext) => PrismSheetBody(
      title: l10n.economyAiStyleSheetTitle,
      message: l10n.economyAiStyleSheetSubject,
      childScrolls: true,
      child: AiStyleGrid(
        selected: selected,
        onSelected: (AiStylePreset style) => Navigator.of(sheetContext).pop(style),
      ),
    ),
  );
}

/// Two columns of 9:16 previews with the style name under each. Rows size to their text, so large text never clips.
class AiStyleGrid extends StatelessWidget {
  const AiStyleGrid({super.key, required this.selected, required this.onSelected});

  static const int columns = 2;

  final AiStylePreset selected;
  final ValueChanged<AiStylePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    const List<AiStylePreset> styles = AiStylePreset.values;
    final int rows = (styles.length / columns).ceil();
    return ListView.separated(
      padding: PrismBottomSheet.bodyPadding.copyWith(
        top: 0,
        bottom: PrismSpace.xl + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.lg),
      itemBuilder: (_, int row) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int column = 0; column < columns; column++) ...<Widget>[
            if (column > 0) const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: row * columns + column < styles.length
                  ? _SheetStyleTile(
                      style: styles[row * columns + column],
                      selected: styles[row * columns + column] == selected,
                      onTap: () {
                        PrismHaptics.selection();
                        onSelected(styles[row * columns + column]);
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetStyleTile extends StatelessWidget {
  const _SheetStyleTile({required this.style, required this.selected, required this.onTap});

  final AiStylePreset style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.sm);
    final String label = aiStyleLabel(l10n, style);
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.economyAiStyleSemantics(label),
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 9 / 16,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        AiStyleSample(style: style, size: AiStyleSampleSize.sheet),
                        Positioned(
                          top: PrismSpace.xs,
                          right: PrismSpace.xs,
                          child: AiStyleTick(selected: selected),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PrismSpace.xs),
              Text(label, style: PrismTextStyles.rowTitle(context).copyWith(color: selected ? cs.primary : null)),
            ],
          ),
        ),
      ),
    );
  }
}
