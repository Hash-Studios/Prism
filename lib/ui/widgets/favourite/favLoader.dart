// import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/ui/widgets/favourite/favGrid.dart';
import 'package:Prism/ui/widgets/home/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FavLoader extends StatefulWidget {
  final Future<List> future;
  FavLoader({this.future});
  @override
  _FavLoaderState createState() => _FavLoaderState();
}

class _FavLoaderState extends State<FavLoader> {
  Future<List> _future;
  @override
  void initState() {
    super.initState();
    // _future =
    //     Provider.of<FavouriteProvider>(context, listen: false).getDataBase();
    _future = widget.future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (ctx, snapshot) {
        // if (snapshot.hasData) {
        //   print("has data");
        //   return FavouriteGrid();
        // } else {
        //   print("snapshot waiting");
        //   return CircularProgressIndicator();
        // }
        if (snapshot == null) {
          print("snapshot null");
          // return CircularProgressIndicator();
          return LoadingCards();
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          print("snapshot none, waiting");
          //   return CircularProgressIndicator();
          return LoadingCards();
        } else {
          return FavouriteGrid();
        }
      },
    );
  }
}
