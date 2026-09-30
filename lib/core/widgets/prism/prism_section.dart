import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Title above a group of content, with an optional action at the end (for example "See all").
class PrismSectionHeader extends StatelessWidget {
  const PrismSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(top: PrismSpace.xl, bottom: PrismSpace.sm),
    this.small = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  /// A quieter label for groups inside a list or a sheet (13 w600, muted).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: small
                    ? PrismTextStyles.caption(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600)
                    : PrismTextStyles.sectionTitle(context),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
                textStyle: PrismTextStyles.button.copyWith(fontSize: 14),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
