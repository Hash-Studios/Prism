import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/prism_color_scheme.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Accent colours the user can pick from.
const List<Color> prismAccentSwatches = <Color>[
  Color(0xFFE57697),
  Color(0xFFFF0000),
  Color(0xFFF44436),
  Color(0xFFe91e63),
  Color(0xFF9c27b0),
  Color(0xFF673ab7),
  Color(0xFF0000FF),
  Color(0xFF1976D2),
  Color(0xFF03a9f4),
  Color(0xFF00bcd4),
  Color(0xFF009688),
  Color(0xFF4caf50),
  Color(0xFF00FF00),
  Color(0xFF8bc34a),
  Color(0xFFcddc39),
  Color(0xFFffeb3b),
  Color(0xFFffc107),
  Color(0xFFff9800),
  Color(0xFFff5722),
  Color(0xFF795548),
  Color(0xFF9e9e9e),
  Color(0xFF607d8b),
];

/// A small phone drawn from the colours of [theme]: its background, raised tiles and the accent. Changing [theme]
/// or [previewKey] cross-fades to the new look.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.theme, required this.previewKey});

  final ThemeData theme;
  final Object previewKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.base),
      switchInCurve: PrismCurves.enter,
      child: _Phone(key: ValueKey<Object>(previewKey), scheme: theme.colorScheme),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone({super.key, required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    Widget tile() => Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(PrismRadius.xs),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 104,
        height: 200,
        padding: const EdgeInsets.all(PrismSpace.sm),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(PrismRadius.pill),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: PrismSpace.sm),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: Row(children: <Widget>[tile(), const SizedBox(width: 6), tile()])),
                  const SizedBox(height: 6),
                  Expanded(child: Row(children: <Widget>[tile(), const SizedBox(width: 6), tile()])),
                ],
              ),
            ),
            const SizedBox(height: PrismSpace.sm),
            Container(
              height: 22,
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(PrismRadius.pill)),
              alignment: Alignment.center,
              child: Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal list of theme swatches: the theme background, a few tiles and an accent dot, with the name below.
class ThemeSwatchRow extends StatelessWidget {
  const ThemeSwatchRow({
    super.key,
    required this.themes,
    required this.selectedId,
    required this.accent,
    required this.onSelect,
  });

  final List<PrismThemeOption> themes;
  final String selectedId;
  final Color accent;
  final ValueChanged<PrismThemeOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72 + PrismSpace.xs + MediaQuery.textScalerOf(context).scale(18),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: PrismSpace.pageInsets,
        itemCount: themes.length,
        separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.sm),
        itemBuilder: (context, index) {
          final PrismThemeOption option = themes[index];
          return _Swatch(
            option: option,
            accent: accent,
            selected: option.id == selectedId,
            onTap: () => onSelect(option),
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.option, required this.accent, required this.selected, required this.onTap});

  final PrismThemeOption option;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ColorScheme scheme = option.theme.colorScheme;
    return PressScale(
      child: Semantics(
        button: true,
        selected: selected,
        label: '${option.label} theme',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedContainer(
                  duration: context.motion(PrismDurations.fast),
                  curve: PrismCurves.enter,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                    border: Border.all(
                      color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.12),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(PrismSpace.xs),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Row(
                          children: <Widget>[
                            for (int i = 0; i < 2; i++) ...<Widget>[
                              if (i > 0) const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(PrismRadius.xs),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      if (selected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: PrismSpace.xs),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.caption(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round accent swatches in a wrap. The selected one shows a tick and a ring.
class AccentWrap extends StatelessWidget {
  const AccentWrap({super.key, required this.selected, required this.onSelect});

  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: PrismSpace.pageInsets,
      child: Wrap(
        spacing: PrismSpace.xs,
        runSpacing: PrismSpace.xs,
        children: <Widget>[
          for (int i = 0; i < prismAccentSwatches.length; i++)
            _AccentDot(
              color: prismAccentSwatches[i],
              index: i,
              selected: selected == prismAccentSwatches[i],
              ring: cs.onSurface,
              onTap: () => onSelect(prismAccentSwatches[i]),
            ),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.index,
    required this.selected,
    required this.ring,
    required this.onTap,
  });

  final Color color;
  final int index;
  final bool selected;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Accent colour ${index + 1} of ${prismAccentSwatches.length}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? ring : ring.withValues(alpha: 0.12), width: selected ? 2.5 : 1),
                ),
                child: AnimatedOpacity(
                  duration: context.motion(PrismDurations.fast),
                  opacity: selected ? 1 : 0,
                  child: Icon(Icons.check_rounded, size: 20, color: prismOnColor(color)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
