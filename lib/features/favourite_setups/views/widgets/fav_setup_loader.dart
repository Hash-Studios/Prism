import 'package:Prism/features/favourite_setups/views/widgets/fav_setup_grid.dart';
import 'package:Prism/features/setups/views/widgets/loading_setup_cards.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FavSetupLoader extends StatefulWidget {
  final Future<List?>? future;
  const FavSetupLoader({this.future});
  @override
  _FavSetupLoaderState createState() => _FavSetupLoaderState();
}

class _FavSetupLoaderState extends State<FavSetupLoader> {
  Future<List?>? _future;
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
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none) {
          logger.d("snapshot none, waiting");
          return const LoadingSetupCards();
        } else {
          return const FavouriteSetupGrid();
        }
      },
    );
  }
}
