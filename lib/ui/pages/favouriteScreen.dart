import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/ui/widgets/bottomNavBar.dart';
import 'package:Prism/ui/widgets/favLoader.dart';
import 'package:Prism/ui/widgets/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavouriteScreen extends StatelessWidget {
  FavouriteScreen({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        child: HeadingChipBar(
          current: "Favourites",
        ),
        preferredSize: Size(double.infinity, 55),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: BottomBar(
        child: SafeArea(
          child: FavLoader(
            future: Provider.of<FavouriteProvider>(context, listen: false)
                .getDataBase(),
          ),
        ),
      ),
    );
  }
}
