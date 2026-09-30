import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How much weight a [PrismButton] carries. Use one [primary] per screen.
enum PrismButtonVariant {
  /// The one main action. Filled with the accent.
  primary,

  /// A supporting action. Neutral fill.
  tonal,

  /// A low-weight action. Text only.
  ghost,

  /// Deletes or removes something. Filled with the error colour.
  danger,
}

enum PrismButtonSize {
  /// 52 high. Page and sheet actions.
  large,

  /// 40 high. Actions inside cards and rows.
  compact,
}

/// The app's button. It scales down while pressed and shows a spinner in place of its label while [loading].
class PrismButton extends StatelessWidget {
  const PrismButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PrismButtonVariant.primary,
    this.size = PrismButtonSize.large,
    this.icon,
    this.trailing,
    this.loading = false,
    this.expand = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final PrismButtonVariant variant;
  final PrismButtonSize size;
  final IconData? icon;

  /// A widget after the label, for example a coin icon next to a price.
  final Widget? trailing;

  /// Shows a spinner and blocks taps.
  final bool loading;

  /// Fills the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool large = size == PrismButtonSize.large;
    final (Color bg, Color fg) = switch (variant) {
      PrismButtonVariant.primary => (cs.primary, cs.onPrimary),
      PrismButtonVariant.tonal => (cs.onSurface.withValues(alpha: 0.08), cs.onSurface),
      PrismButtonVariant.ghost => (Colors.transparent, cs.onSurface),
      PrismButtonVariant.danger => (cs.error, cs.onError),
    };
    final bool enabled = onPressed != null && !loading;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[Icon(icon, size: large ? 20 : 18), const SizedBox(width: PrismSpace.xs)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (trailing != null) ...<Widget>[const SizedBox(width: PrismSpace.xs), trailing!],
      ],
    );
    return PressScale(
      enabled: enabled,
      child: FilledButton(
        onPressed: loading
            ? () {}
            : onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: variant == PrismButtonVariant.ghost
              ? Colors.transparent
              : cs.onSurface.withValues(alpha: 0.06),
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          minimumSize: Size(expand ? double.infinity : 0, large ? 52 : 40),
          padding: EdgeInsets.symmetric(horizontal: large ? PrismSpace.xl : PrismSpace.md),
          textStyle: large ? PrismTextStyles.button : PrismTextStyles.button.copyWith(fontSize: 14),
          splashFactory: NoSplash.splashFactory,
        ),
        child: loading
            ? SizedBox.square(
                dimension: large ? 20 : 16,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
              )
            : content,
      ),
    );
  }
}

/// A round icon button with a 44 point tap target. [tooltip] is required: it is also the screen reader label.
class PrismIconButton extends StatelessWidget {
  const PrismIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.onImage = false,
    this.size = 44,
    this.iconSize = 22,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Draws a neutral circle behind the icon.
  final bool filled;

  /// For buttons that sit on a wallpaper: a dark translucent circle and a white icon on every theme.
  final bool onImage;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = color ?? (onImage ? Colors.white : cs.onSurface);
    final Color? bg = onImage
        ? Colors.black.withValues(alpha: 0.38)
        : filled
        ? cs.onSurface.withValues(alpha: 0.08)
        : null;
    return PressScale(
      enabled: onPressed != null,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        color: fg,
        disabledColor: fg.withValues(alpha: 0.38),
        style: IconButton.styleFrom(
          backgroundColor: bg,
          minimumSize: Size.square(size),
          fixedSize: Size.square(size),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
