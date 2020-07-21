import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/favourite/favLoader.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
import 'package:Prism/ui/widgets/home/headingChipBar.dart';
import 'package:Prism/ui/widgets/offlineBanner.dart';
import 'package:connectivity_widget/connectivity_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavouriteScreen extends StatelessWidget {
  FavouriteScreen({
    Key key,
  }) : super(key: key);

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: PreferredSize(
          child: HeadingChipBar(
            current: "Favourites",
          ),
          preferredSize: Size(double.infinity, 55),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: ConnectivityWidget(
          offlineBanner: OfflineBanner(),
          builder: (context, isOnline) => BottomBar(
            child: SafeArea(
              child: FavLoader(
                future: Provider.of<FavouriteProvider>(context, listen: false)
                    .getDataBase(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
