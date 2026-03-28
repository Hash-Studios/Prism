import 'package:flutter/material.dart';

/// Shared modal chrome for AI flows (submit, variation, Create sheet entry).
abstract final class AiSheetChrome {
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(20, 12, 20, 24);

  static const double handleWidth = 32;

  static const double handleHeight = 4;
}

class AiSheetDragHandle extends StatelessWidget {
  const AiSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        height: AiSheetChrome.handleHeight,
        width: AiSheetChrome.handleWidth,
        decoration: BoxDecoration(
          color: Theme.of(context).hintColor,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35), width: 0.5),
        ),
      ),
    );
  }
}
