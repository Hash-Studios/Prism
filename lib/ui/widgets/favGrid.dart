import 'package:Prism/ui/widgets/gridLoader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({
    Key key,
    @required this.controller,
    @required this.animation,
  }) : super(key: key);

  final ScrollController controller;
  final Animation<Color> animation;
  @override
  _FavouriteGridState createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid> {
  final databaseReference = Firestore.instance;
  Future<QuerySnapshot> dbr;
  List liked = [];
  SharedPreferences prefs;
  String userId = '';
  List data = [];
  var refreshFavKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    readLocal().then((value) {
      dbr = databaseReference
          .collection("users")
          .document(value)
          .collection("images")
          .getDocuments();
    });
    setState(() {});
  }

  Future<String> readLocal() async {
    prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('id');
    setState(() {});
    return userId;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<Null> refreshList() async {
    refreshFavKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    setState(() {
      liked = [];
    });
    setState(() {
      dbr = databaseReference
          .collection("users")
          .document(userId)
          .collection("images")
          .getDocuments();
    });

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      key: refreshFavKey,
      onRefresh: refreshList,
      child: FutureBuilder(
          future: dbr,
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasData) {
              data = [];
              liked = [];
              snapshot.data.documents.forEach((f) => data.add(f.data));
              if (data.toString() != '[]') {
                data.forEach(
                  (v) => liked.add(v["id"]),
                );
                return new Container(
                    height: double.infinity,
                    color: Theme.of(context).primaryColor,
                    child: Scrollbar(
                      child: GridView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
                          itemCount: data.length,
                          gridDelegate:
                              new SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2, childAspectRatio: 0.75),
                          itemBuilder: (BuildContext context, int index) {
                            return new GestureDetector(
                              child: new Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(24))),
                                elevation: 0.0,
                                semanticContainer: true,
                                margin: EdgeInsets.fromLTRB(4, 4, 4, 4),
                                clipBehavior: Clip.antiAliasWithSaveLayer,
                                child: new Container(
                                    child: Image.network(data[index]["thumb"])
                                    // new Hero(
                                    //     tag:
                                    //         "https://whvn.cc/${data[index]["url"].substring(16)}",
                                    //     child: Image(
                                    //       image: CacheImage(
                                    //         data[index]["thumb"],
                                    //       ),
                                    //       fit: BoxFit.cover,
                                    //     ))
                                    ),
                              ),
                              onTap: () {},
                            );
                          }),
                    ));
              } else {
                return Container(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Image(
                          image: Theme.of(context).primaryColor ==
                                  Color(0xFFFFFFFF)
                              ? AssetImage("assets/images/oopssw.png")
                              : Theme.of(context).primaryColor ==
                                      Color(0xFF272727)
                                  ? AssetImage("assets/images/oopsdb.png")
                                  : Theme.of(context).primaryColor ==
                                          Color(0xFF000000)
                                      ? AssetImage("assets/images/oopsab.png")
                                      : Theme.of(context).primaryColor ==
                                              Color(0xFF263238)
                                          ? AssetImage(
                                              "assets/images/oopscd.png")
                                          : AssetImage(
                                              "assets/images/oopsmc.png"),
                          height: 600,
                          width: 600,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            "Oops!",
                            style: TextStyle(
                                fontSize: 30,
                                color: Theme.of(context).secondaryHeaderColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Text(
                          "Double tap some awesome\nwallpapers to add them here.",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).secondaryHeaderColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
            return LoadingCards(
                controller: widget.controller, animation: widget.animation);
          }),
    );
  }

  void createRecord2(
      String id,
      String url,
      String thumb,
      String color,
      String color2,
      String views,
      String resolution,
      String created,
      String fav,
      String size) async {
    await databaseReference
        .collection("users")
        .document(userId)
        .collection("images")
        .document(id)
        .setData({
      "id": id,
      "url": url,
      "thumb": thumb,
      "color": color,
      "color2": color2,
      "views": views,
      "resolution": resolution,
      "created": created,
      "fav": fav,
      "size": size,
    });
  }

  void getData2() {
    databaseReference
        .collection("users")
        .document(userId)
        .collection("images")
        .getDocuments()
        .then((QuerySnapshot snapshot) {
      snapshot.documents.forEach((f) => print('${f.data}}'));
    });
  }

  void deleteData2(String id) {
    try {
      databaseReference
          .collection("users")
          .document(userId)
          .collection("images")
          .document(id)
          .delete();
    } catch (e) {
      print(e.toString());
    }
  }
}
