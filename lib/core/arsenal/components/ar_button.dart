import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/spacing.dart';
import 'package:Prism/core/arsenal/typography.dart';
import 'package:flutter/material.dart';

enum _ArButtonVariant { primary, secondary, ghost }

class ArButton extends StatelessWidget {
  const ArButton._({
    super.key,
    required this.label,
    required this.variant,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
  });

  factory ArButton.primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    double? width,
  }) => ArButton._(
    key: key,
    label: label,
    variant: _ArButtonVariant.primary,
    onPressed: onPressed,
    isLoading: isLoading,
    isDisabled: isDisabled,
    width: width,
  );

  factory ArButton.secondary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    double? width,
  }) => ArButton._(
    key: key,
    label: label,
    variant: _ArButtonVariant.secondary,
    onPressed: onPressed,
    isLoading: isLoading,
    isDisabled: isDisabled,
    width: width,
  );

  factory ArButton.ghost({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    double? width,
  }) => ArButton._(
    key: key,
    label: label,
    variant: _ArButtonVariant.ghost,
    onPressed: onPressed,
    isLoading: isLoading,
    isDisabled: isDisabled,
    width: width,
  );

  final String label;
  final _ArButtonVariant variant;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;

  bool get _interactive => !isDisabled && !isLoading;

  Color get _backgroundColor {
    switch (variant) {
      case _ArButtonVariant.primary:
        return ArsenalColors.accent;
      case _ArButtonVariant.secondary:
      case _ArButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _labelColor {
    switch (variant) {
      case _ArButtonVariant.primary:
        return Colors.white;
      case _ArButtonVariant.secondary:
      case _ArButtonVariant.ghost:
        return ArsenalColors.accent;
    }
  }

  Border? get _border {
    switch (variant) {
      case _ArButtonVariant.primary:
      case _ArButtonVariant.ghost:
        return null;
      case _ArButtonVariant.secondary:
        return Border.all(color: ArsenalColors.accent, width: 1.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: _interactive ? 1.0 : 0.3,
      child: GestureDetector(
        onTap: _interactive ? onPressed : null,
        child: Container(
          width: width,
          height: ArsenalSpacing.buttonHeight,
          decoration: BoxDecoration(color: _backgroundColor, border: _border),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: ArsenalSpacing.lg),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_labelColor),
                  ),
                )
              : Text(label.toUpperCase(), style: ArsenalTypography.buttonLabel.copyWith(color: _labelColor)),
        ),
      ),
    );

    return button;
  }
}
