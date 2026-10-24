import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:flutter/material.dart';

/// One tappable action in [WallpaperActionBar]. [child] is the button, [label] its tooltip.
class WallpaperBarAction {
  const WallpaperBarAction({required this.label, required this.child});

  final String label;
  final Widget child;
}

/// The row under the wallpaper card: plain icon [actions] at the start, then the [secondary] icons and the labelled
/// [primary] action at the end. It paints no surface of its own.
class WallpaperActionBar extends StatelessWidget {
  const WallpaperActionBar({required this.primary, required this.actions, this.secondary = const [], super.key});

  /// Height of the row, including the space above the buttons.
  static const double height = 60;

  final WallpaperBarAction primary;
  final List<WallpaperBarAction> actions;

  /// Icon actions that belong with [primary], placed just before it.
  final List<WallpaperBarAction> secondary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: FlatMenuButtons(
                iconSize: 24,
                padding: const EdgeInsets.all(13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final WallpaperBarAction action in actions)
                          Tooltip(message: action.label, child: action.child),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final WallpaperBarAction action in secondary)
                          Tooltip(message: action.label, child: action.child),
                        Tooltip(message: primary.label, triggerMode: TooltipTriggerMode.manual, child: primary.child),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
