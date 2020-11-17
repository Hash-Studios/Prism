import 'package:Prism/ui/widgets/favourite/favSetupGrid.dart';
import 'package:Prism/ui/widgets/setups/loadingSetups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FavSetupLoader extends StatefulWidget {
  final Future<List> future;
  const FavSetupLoader({this.future});
  @override
  _FavSetupLoaderState createState() => _FavSetupLoaderState();
}

class _FavSetupLoaderState extends State<FavSetupLoader> {
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
          return const LoadingSetupCards();
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
          debugPrint("snapshot none, waiting");
          return const LoadingSetupCards();
        } else {
          return const FavouriteSetupGrid();
        }
      },
    );
  }
}
