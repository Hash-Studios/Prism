import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:flutter/material.dart';

/// One tappable action in [WallpaperActionBar]. [child] is the button, [label] its tooltip.
class WallpaperBarAction {
  const WallpaperBarAction({required this.label, required this.child});

  final String label;
  final Widget child;
}

/// Compact row of actions: a primary action that carries its own label, then plain icon actions.
/// It paints no surface of its own. It sits on the details panel, so the two read as one unit.
class WallpaperActionBar extends StatelessWidget {
  const WallpaperActionBar({required this.primary, required this.actions, super.key});

  /// Height of the row, without the bottom safe area.
  static const double height = 66;

  final WallpaperBarAction primary;
  final List<WallpaperBarAction> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: FlatMenuButtons(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Tooltip(message: primary.label, triggerMode: TooltipTriggerMode.manual, child: primary.child),
                      for (final WallpaperBarAction action in actions)
                        Tooltip(message: action.label, child: action.child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
