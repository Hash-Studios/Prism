import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
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
      actions: const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: CoinBalanceChip(sourceTag: 'coins.chip.heading_bar'),
        ),
      ],
    );
  }
}
