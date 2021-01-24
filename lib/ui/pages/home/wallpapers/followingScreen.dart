import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/following/followingFeed.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    Key key,
  }) : super(key: key);

  @override
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  Stream<List<DocumentSnapshot>> _stream;
  Firestore firestore = Firestore.instance;
  CollectionReference walls;
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    debugPrint("Bye! Have a good day!");
    return true;
  }

  @override
  void initState() {
    super.initState();
    walls = firestore.collection('walls');
    _stream = getFollowingFeed();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: StreamBuilder<List<DocumentSnapshot>>(
        stream: _stream, // async work
        builder: (BuildContext context,
            AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: Loader());
            case ConnectionState.none:
              return Center(child: Loader());
            default:
              if (snapshot.hasError) {
                debugPrint(snapshot.error.toString());
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const <Widget>[
                    Spacer(),
                    Center(child: Text("Can't connect to the Servers!")),
                    Spacer(),
                  ],
                );
              } else {
                print(snapshot.data);
                return StaggeredGridView.builder(
                  gridDelegate:
                      SliverStaggeredGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    staggeredTileCount: snapshot.data.length,
                    staggeredTileBuilder: (index) {
                      return StaggeredTile.fit(1);
                    },
                  ),
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                        imageUrl:
                            snapshot.data[index]["wallpaper_url"].toString());
                  },
                );
              }
          }
        },
      ),
    );
  }
}
