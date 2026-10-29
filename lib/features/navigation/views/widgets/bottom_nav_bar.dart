import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

/// The bar's default offset, the pill height, and a gap.
const double _snackBarBottomInset = 10 + 56 + PrismSpace.xs;

/// Hosts the tab content with the floating pill and create button above it. The bar hides while the user scrolls
/// down; the package's scroll-to-top button takes its place.
///
/// Where iOS keeps a safe column on the right of a portrait screen (the iPhone Duo outer screen puts the status bar
/// there), the pill and the create button stand in that column instead, always visible.
class BottomBar extends StatelessWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double railWidth = sideSafeColumnWidth(context);
    if (railWidth > 0) {
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            Expanded(
              child: SideSafeColumnScope(
                nativeWidth: railWidth,
                child: MediaQuery.removePadding(context: context, removeRight: true, child: child ?? const SizedBox()),
              ),
            ),
            SizedBox(
              width: railWidth,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 12;
                  return SingleChildScrollView(
                    primary: false,
                    reverse: true,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - bottomPadding).clamp(0.0, double.infinity),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PrismBottomNav(axis: Axis.vertical),
                            SizedBox(height: 12),
                            PrismFab(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
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
      // The tab Scaffolds do not know about the pill, so lift their floating snackbars above it.
      body: Theme(
        data: theme.copyWith(
          snackBarTheme: theme.snackBarTheme.copyWith(
            insetPadding: const EdgeInsets.fromLTRB(15, 5, 15, _snackBarBottomInset),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
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
