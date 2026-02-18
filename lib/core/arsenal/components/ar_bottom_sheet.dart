import 'package:Prism/core/arsenal/colors.dart';
import 'package:Prism/core/arsenal/spacing.dart';
import 'package:Prism/core/arsenal/theme.dart';
import 'package:Prism/core/arsenal/typography.dart';
import 'package:flutter/material.dart';

class ArBottomSheet {
  ArBottomSheet._();

  static Future<T?> show<T>(BuildContext context, {required Widget child, String? title}) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: arsenalDarkTheme,
        child: _ArBottomSheetContent(title: title, child: child),
      ),
    );
  }
}

class _ArBottomSheetContent extends StatelessWidget {
  const _ArBottomSheetContent({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ArsenalColors.surface,
        // Zero border radius — sharp corners
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: ArsenalSpacing.md, bottom: ArsenalSpacing.sm),
              child: Container(width: 40, height: 4, color: ArsenalColors.border),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ArsenalSpacing.md,
                ArsenalSpacing.sm,
                ArsenalSpacing.md,
                ArsenalSpacing.md,
              ),
              child: Text(title!, style: ArsenalTypography.subheadingMedium),
            ),
            Container(height: 1, color: ArsenalColors.border),
          ],
          child,
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
