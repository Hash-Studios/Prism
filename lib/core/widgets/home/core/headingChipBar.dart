import 'package:Prism/core/router/app_router.dart';
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
          }),
      title: Text(
        widget.current,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }
}
