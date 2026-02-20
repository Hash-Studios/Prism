import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/spacing.dart';
import 'package:Prism/core/arsenal/typography.dart';
import 'package:flutter/material.dart';

class ArAppBar extends StatelessWidget {
  const ArAppBar({
    super.key,
    this.title,
    this.action,
    this.bottom,
    this.showBackButton,
    this.padding = const EdgeInsets.symmetric(horizontal: ArsenalSpacing.md),
  });

  /// Page title — displayed UPPERCASE in displayMedium style.
  final String? title;

  /// Optional widget anchored to the right of the title row.
  final Widget? action;

  /// Optional slot below the title row (search bar, chip row, tabs).
  /// Rendered at full width; caller controls its own padding.
  final Widget? bottom;

  /// `true` = force show, `false` = force hide, `null` = auto (Navigator.canPop).
  final bool? showBackButton;

  /// Horizontal padding for the title row. Defaults to [ArsenalSpacing.md].
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final showBack = showBackButton ?? canPop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding.horizontal / 2),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                if (showBack)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.only(right: ArsenalSpacing.sm),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: ArsenalSpacing.iconSm,
                        color: ArsenalColors.onBackground,
                      ),
                    ),
                  ),
                if (title != null)
                  Flexible(
                    child: Text(
                      title!.toUpperCase(),
                      style: ArsenalTypography.displayMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (action != null) ...[const Spacer(), action!],
              ],
            ),
          ),
        ),
        if (bottom != null) bottom!,
        Container(height: 1, color: ArsenalColors.border),
      ],
    );
  }
}
