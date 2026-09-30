import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One row in a list or a [PrismGroup]: an icon tile, a title, an optional subtitle and a trailing part.
class PrismRow extends StatelessWidget {
  const PrismRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron,
    this.padding = const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
  });

  final String title;

  /// Icon shown in a small rounded tile. Ignored when [leading] is set.
  final IconData? icon;

  /// Replaces the icon tile, for example an avatar.
  final Widget? leading;
  final String? subtitle;

  /// Short current value shown before the chevron, for example "High".
  final String? value;

  /// Replaces the chevron, for example a [Switch].
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Draws the row in the error colour.
  final bool destructive;

  /// Defaults to true when [onTap] is set and [trailing] is null.
  final bool? showChevron;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = destructive ? cs.error : cs.onSurface;
    final bool chevron = showChevron ?? (onTap != null && trailing == null);
    final Widget? lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PrismRadius.xs + 2),
                ),
                child: Icon(icon, size: 18, color: fg),
              ));
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: padding,
        child: Row(
          children: <Widget>[
            if (lead != null) ...<Widget>[lead, const SizedBox(width: PrismSpace.sm)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: PrismTextStyles.rowTitle(context).copyWith(color: fg)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: PrismTextStyles.caption(context).copyWith(fontSize: 13, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (value != null) ...<Widget>[
              const SizedBox(width: PrismSpace.sm),
              Text(value!, style: PrismTextStyles.body(context)),
            ],
            if (trailing != null) ...<Widget>[const SizedBox(width: PrismSpace.sm), trailing!],
            if (chevron) ...<Widget>[
              const SizedBox(width: PrismSpace.xxs),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// A [PrismRow] with a switch. The whole row toggles it.
class PrismSwitchRow extends StatelessWidget {
  const PrismSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    void toggle(bool next) {
      HapticFeedback.selectionClick();
      onChanged?.call(next);
    }

    return MergeSemantics(
      child: PrismRow(
        title: title,
        icon: icon,
        subtitle: subtitle,
        onTap: onChanged == null ? null : () => toggle(!value),
        trailing: Switch(value: value, onChanged: onChanged == null ? null : toggle),
      ),
    );
  }
}
