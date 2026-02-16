import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class HeadingChipBar extends StatefulWidget {
  final String current;
  const HeadingChipBar({super.key, required this.current});

  @override
  _HeadingChipBarState createState() => _HeadingChipBarState();
}

class _HeadingChipBarState extends State<HeadingChipBar> {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leading: IconButton(
          icon: Icon(JamIcons.chevron_left, color: Theme.of(context).colorScheme.secondary),
          onPressed: () {
            Navigator.pop(context);
            if (navStack.length > 1) {
              navStack.removeLast();
              if ((navStack.last == "Wallpaper") ||
                  (navStack.last == "Search Wallpaper") ||
                  (navStack.last == "SharedWallpaper") ||
                  (navStack.last == "SetupView")) {}
            }
            logger.d(navStack.toString());
          }),
      title: Text(
        widget.current,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }
}
