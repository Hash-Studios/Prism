import 'package:Prism/ui/widgets/favourite/favGrid.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FavLoader extends StatefulWidget {
  final Future<List> future;
  const FavLoader({this.future});
  @override
  _FavLoaderState createState() => _FavLoaderState();
}

class _FavLoaderState extends State<FavLoader> {
  Future<List> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (ctx, snapshot) {
        if (snapshot == null) {
          debugPrint("snapshot null");
          return const LoadingCards();
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          debugPrint("snapshot none, waiting");
          return const LoadingCards();
        } else {
          return const FavouriteGrid();
        }
      },
    );
  }
}
