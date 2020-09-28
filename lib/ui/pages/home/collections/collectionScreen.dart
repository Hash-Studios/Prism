import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';
import 'package:flutter/material.dart';

class CollectionScreen extends StatefulWidget {
  CollectionScreen({
    Key key,
  }) : super(key: key);

  @override
  _CollectionScreenState createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack);
    return true;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: new FutureBuilder<Map>(
        future: getCollections(), // async work
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: new Loader());
            case ConnectionState.none:
              return Center(child: new Loader());
            default:
              if (snapshot.hasError)
                return RefreshIndicator(
                    onRefresh: () async {
                      getCollections();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Spacer(),
                        Center(
                            child: new Text("Can't connect to the Servers!")),
                        Spacer(),
                      ],
                    ));
              else {
                return CollectionsGrid();
              }
          }
        },
      ),
    );
  }
}
