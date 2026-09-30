import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Meaning of a [PrismTag]'s colour.
enum PrismTone { neutral, accent, success, warning, danger }

/// A small status label: "Pending", "Pro", "New". Not tappable.
class PrismTag extends StatelessWidget {
  const PrismTag({super.key, required this.label, this.tone = PrismTone.neutral, this.icon});

  final String label;
  final PrismTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color c = switch (tone) {
      PrismTone.neutral => cs.onSurface,
      PrismTone.accent => cs.primary,
      PrismTone.success => PrismColors.success,
      PrismTone.warning => PrismColors.warning,
      PrismTone.danger => cs.error,
    };
    // Status colours are tuned for fills. For text, mix them toward the text colour so they stay readable.
    final Color fg = tone == PrismTone.neutral
        ? cs.onSurface.withValues(alpha: 0.8)
        : Color.lerp(c, cs.onSurface, 0.25)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: tone == PrismTone.neutral ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: PrismTextStyles.caption(context).copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

/// A round profile picture with a hairline ring. Shows the first letter of [name] when there is no image.
class PrismAvatar extends StatelessWidget {
  const PrismAvatar({super.key, this.url, this.name, this.size = 44});

  final String? url;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String initial = (name ?? '').trim().isEmpty ? '' : name!.trim().characters.first.toUpperCase();
    final Widget fallback = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: initial.isEmpty
            ? Icon(Icons.person_rounded, size: size * 0.5, color: cs.onSurface.withValues(alpha: 0.5))
            : Text(initial, style: PrismTextStyles.cardTitle(context).copyWith(fontSize: size * 0.4)),
      ),
    );
    final String? src = url?.trim();
    return Container(
      width: size,
      height: size,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: ClipOval(
        child: src == null || src.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: src,
                fit: BoxFit.cover,
                fadeInDuration: context.motion(PrismDurations.fast),
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// A row of two to four exclusive choices with a thumb that slides to the selected one.
class PrismSegmented<T> extends StatelessWidget {
  const PrismSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T>? onChanged;
  final IconData? Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int index = values.indexOf(selected).clamp(0, values.length - 1);
    final double x = values.length == 1 ? 0 : -1 + 2 * index / (values.length - 1);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            alignment: Alignment(x, 0),
            duration: context.motion(PrismDurations.base),
            curve: PrismCurves.move,
            child: FractionallySizedBox(
              widthFactor: 1 / values.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: cs.onSurface, borderRadius: BorderRadius.circular(PrismRadius.pill)),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              for (final T value in values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == selected,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onChanged == null || value == selected
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              onChanged!(value);
                            },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (iconOf?.call(value) != null) ...<Widget>[
                              Icon(iconOf!(value), size: 16, color: value == selected ? cs.surface : cs.onSurface),
                              const SizedBox(width: 6),
                            ],
                            AnimatedDefaultTextStyle(
                              duration: context.motion(PrismDurations.fast),
                              style: PrismTextStyles.rowTitle(
                                context,
                              ).copyWith(fontSize: 14, color: value == selected ? cs.surface : cs.onSurface),
                              child: Text(labelOf(value), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
