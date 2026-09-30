import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/features/favourite_setups/views/widgets/fav_setup_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FavouriteSetupScreen extends StatelessWidget {
  const FavouriteSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: "Favourites"),
      ),
      body: const FavouriteSetupGrid(),
    );
  }
}
