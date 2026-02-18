import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_loader.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FavouriteWallpaperScreen extends StatelessWidget {
  const FavouriteWallpaperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: "Favourites"),
      ),
      body: BottomBar(child: FavLoader(future: context.favouriteWallsAdapter(listen: false).getDataBase())),
    );
  }
}
