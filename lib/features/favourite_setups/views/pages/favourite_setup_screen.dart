import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/favourite_setups/views/widgets/fav_setup_loader.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';

class FavouriteSetupScreen extends StatelessWidget {
  const FavouriteSetupScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        popNavStackIfPossible();
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
            child: FavSetupLoader(
              future: context.favouriteSetupsAdapter(listen: false).getDataBase(),
            ),
          )),
    );
  }
}
