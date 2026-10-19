import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

/// Hosts the tab content with the floating pill and create button above it. The bar hides while the user scrolls
/// down; the package's scroll-to-top button takes its place.
class BottomBar extends StatelessWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return floating.BottomBar(
      layout: floating.BottomBarLayout(
        width: MediaQuery.sizeOf(context).width,
        borderRadius: BorderRadius.circular(500),
        fit: StackFit.expand,
      ),
      theme: floating.BottomBarThemeData(
        barDecoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(500)),
        iconDecoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle),
        iconWidth: 32,
        iconHeight: 32,
      ),
      iconTooltip: context.l10n.navigationScrollToTop,
      icon: (width, height) => Icon(JamIcons.arrow_up, color: theme.colorScheme.secondary, size: 16),
      body: child ?? const SizedBox.shrink(),
      child: const Align(
        heightFactor: 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicWidth(child: PrismBottomNav()),
            SizedBox(width: 12),
            PrismFab(),
          ],
        ),
      ),
    );
  }
}
