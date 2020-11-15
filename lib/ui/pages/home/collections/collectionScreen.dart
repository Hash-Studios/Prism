import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';
import 'package:flutter/material.dart';
import 'package:Prism/analytics/analytics_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    Key key,
  }) : super(key: key);

  @override
  _CollectionScreenState createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  void initState() {
    analytics.logEvent(
      name: 'collections_checked',
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: FutureBuilder<Map>(
        future: getCollections(), // async work
        builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: Loader());
            case ConnectionState.none:
              return Center(child: Loader());
            default:
              if (snapshot.hasError) {
                return RefreshIndicator(
                    onRefresh: () async {
                      getCollections();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        Spacer(),
                        Center(child: Text("Can't connect to the Servers!")),
                        Spacer(),
                      ],
                    ));
              } else {
                return CollectionsGrid();
              }
          }
        },
      ),
    );
  }
}
