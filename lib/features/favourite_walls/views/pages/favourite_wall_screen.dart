import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_loader.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';

class FavouriteWallpaperScreen extends StatelessWidget {
  const FavouriteWallpaperScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (navStack.length > 1) navStack.removeLast();
        logger.d(navStack.toString());
        return true;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: const PreferredSize(
            preferredSize: Size(double.infinity, 55),
            child: HeadingChipBar(
              current: "Favourites",
            ),
          ),
          body: BottomBar(
            child: FavLoader(
              future: context.favouriteWallsAdapter(listen: false).getDataBase(),
            ),
          )),
    );
  }
}
