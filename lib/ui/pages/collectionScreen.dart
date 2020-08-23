import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    print(navStack);
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
              return new Text("Loading");
            case ConnectionState.none:
              return new Text("Loading");
            default:
              if (snapshot.hasError)
                return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: Column(
                      children: <Widget>[
                        Spacer(),
                        new Text("Can't connect to the Servers!"),
                        Spacer(),
                      ],
                    ));
              else {
                return ListView.builder(
                    itemCount: snapshot.data.length,
                    itemBuilder: (context, index) {
                      return Container(
                        height: 300,
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(
                              snapshot.data[collectionNames.toList()[index]][0]
                                  ["wallpaper_thumb"],
                            ),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    });
              }
          }
        },
      ),
    );
  }
}
