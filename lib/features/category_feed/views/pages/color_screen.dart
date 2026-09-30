import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/views/widgets/color_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ColorScreen extends StatelessWidget {
  const ColorScreen({super.key, required this.hexColor});

  final String hexColor;

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Colour',
      actions: <Widget>[_ColourBadge(hex: hexColor)],
      body: ColorGrid(hexColor: hexColor),
    );
  }
}

/// A round swatch of the searched colour, with its hex code beside it.
class _ColourBadge extends StatelessWidget {
  const _ColourBadge({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int? value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    final String label = '#${hex.replaceFirst('#', '').toUpperCase()}';
    return Semantics(
      label: 'Colour $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(right: PrismSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (value != null)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF000000 | (value & 0xFFFFFF)),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
                ),
              ),
            const SizedBox(width: PrismSpace.xs),
            Text(label, style: PrismTextStyles.caption(context)),
          ],
        ),
      ),
    );
  }
}
