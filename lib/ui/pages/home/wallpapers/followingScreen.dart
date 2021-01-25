import 'dart:async';

import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({
    Key key,
  }) : super(key: key);

  @override
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  StreamController<QuerySnapshot> _streamController;
  QuerySnapshot finalQuery;
  List<DocumentSnapshot> finalDocs = [];
  List following;
  final Firestore databaseReference = Firestore.instance;
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
    _streamController = StreamController.broadcast();
    _streamController.stream.listen((p) {
      setState(() {
        finalQuery = p;
        finalDocs = [];
        for (final doc in finalQuery.documents) {
          if (following.contains(doc.data["email"])) {
            finalDocs.add(doc);
          }
        }
      });
    });
    load(_streamController);
  }

  load(StreamController<QuerySnapshot> sc) async {
    await databaseReference
        .collection("users")
        .where("email", isEqualTo: main.prefs.get('email'))
        .getDocuments()
        .then((value) {
      following = value.documents[0].data["following"] as List ?? [];
    });
    databaseReference
        .collection("walls")
        .where("review", isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .pipe(sc);
  }

  @override
  void dispose() {
    super.dispose();
    _streamController?.close();
    _streamController = null;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: StaggeredGridView.builder(
        gridDelegate: SliverStaggeredGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          staggeredTileCount: finalDocs != null ? finalDocs.length : 0,
          staggeredTileBuilder: (index) {
            return StaggeredTile.fit(1);
          },
        ),
        itemBuilder: (context, index) {
          return _makeElement(index);
        },
      ),
    );
  }

  Widget _makeElement(int index) {
    if (index >= finalDocs.length) {
      return null;
    }

    return Container(
        padding: EdgeInsets.all(5.0),
        child: CachedNetworkImage(
          imageUrl: finalDocs[index]["wallpaper_thumb"] as String,
        ));
  }
}
