import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallpapers_app/wallheaven.dart';
import 'package:wallpapers_app/display.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Wallpapers extends StatefulWidget {
  String query;
  // Key scaffoldKey;
  Wallpapers(this.query);
  @override
  _WallpapersState createState() => _WallpapersState();
}

class _WallpapersState extends State<Wallpapers> {
  final databaseReference = FirebaseDatabase.instance.reference().child("user");
  final databaseReference2 = Firestore.instance;
  List liked = [];
  List<FlareControls> flareControls;
  List<FlareControls> flareControls2;
<<<<<<< HEAD
=======
  SharedPreferences prefs;
  String userId = '';
  String query = "";
>>>>>>> liked images transferred to cloud firstore
  int adder = 0;
  bool fetchedData = false;
  List wallpapersId = [];
  List wallpapersLinks = [];
  List wallpapersThumbs = [];
  List wallpapersColors = [];
  List wallpapersColors2 = [];
  List wallpapersViews = [];
  List wallpapersResolution = [];
  List wallpapersUrl = [];
  List wallpapersCreatedAt = [];
  List wallpapersFav = [];
  List wallpapersSize = [];
  WallData wallheaven = WallData();
  List<String> items = List.generate(
      20, (number) => "https://via.placeholder.com/300x400.jpg/FFFFFF/FFFFFF");

  void getwalls(String query) async {
    if (this.mounted) {
      setState(() {
        fetchedData = false;
      });
    }
    adder = 0;
    items = List.generate(20,
        (number) => "https://via.placeholder.com/300x400.jpg/FFFFFF/FFFFFF");
    Map data = await wallheaven.getData(query);
    wallpapersId = data["id"];
    wallpapersLinks = data["links"];
    wallpapersThumbs = data["thumbs"];
    wallpapersColors = data["colors"];
    wallpapersColors2 = data["colors2"];
    wallpapersViews = data["views"];
    wallpapersResolution = data["resolution"];
    wallpapersUrl = data["url"];
    wallpapersCreatedAt = data["created_at"];
    wallpapersFav = data["favourites"];
    wallpapersSize = data["size"];
    items =
        List.generate(20, (number) => wallpapersLinks[int.parse('$number')]);
    flareControls = List.generate(20, (number) => FlareControls());
    flareControls2 = List.generate(20, (number) => FlareControls());
    if (this.mounted) {
      setState(() {
        fetchedData = true;
      });
    }
  }

  Future<Null> refreshList() async {
    refreshKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(seconds: 1));
    getwalls(widget.query);
    return null;
  }

  Future<String> readLocal() async {
    prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('id');
    setState(() {});
    return userId;
  }

  ScrollController controller;
  var refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    getwalls(widget.query);
=======
    getwalls(query, widget.width, widget.height);
    readLocal();
>>>>>>> liked images transferred to cloud firstore
    controller = new ScrollController()..addListener(_scrollListener);
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (controller.position.extentAfter < 500) {
      if (adder < 120) {
        if (this.mounted) {
          setState(() {
            adder = adder + 20;
            items.addAll(new List.generate(20,
                (number) => wallpapersLinks[int.parse('${number + adder}')]));
            flareControls
                .addAll(new List.generate(20, (number) => FlareControls()));
            flareControls2
                .addAll(new List.generate(20, (number) => FlareControls()));
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
    return fetchedData
        ? RefreshIndicator(
            key: refreshKey,
            onRefresh: refreshList,
            child: new Container(
                color: DynamicTheme.of(context).data.primaryColor,
                child: Scrollbar(
                  child: GridView.builder(
                      shrinkWrap: true,
                      controller: controller,
                      padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
                      itemCount: items.length,
                      gridDelegate:
                          new SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, childAspectRatio: 0.75),
                      itemBuilder: (BuildContext context, int index) {
                        return new GestureDetector(
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Positioned.fill(
                                child: new Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(24))),
                                  elevation: 0.0,
                                  semanticContainer: true,
                                  margin: EdgeInsets.fromLTRB(4, 4, 4, 4),
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  child: new Container(
                                      child: new Hero(
                                          tag: wallpapersUrl[index],
                                          child: FadeInImage(
                                            fadeInDuration:
                                                Duration(milliseconds: 200),
                                            placeholder: CacheImage(
                                                "https://via.placeholder.com/300x400.jpg/${wallpapersColors[index]}/${wallpapersColors[index]}"),
                                            image: CacheImage(
                                              wallpapersThumbs[index],
                                            ),
                                            fit: BoxFit.cover,
                                          ))),
                                ),
                              ),
                              Positioned(
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: FlareActor(
                                    'assets/animations/like.flr',
                                    controller: flareControls[index],
                                    animation: 'idle',
                                  ),
                                ),
                              ),
                              Positioned(
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: FlareActor(
                                    'assets/animations/dislike.flr',
                                    controller: flareControls2[index],
                                    animation: 'idle',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return Display(
                                      wallpapersLinks[index],
                                      wallpapersThumbs[index],
                                      wallpapersColors[index],
                                      wallpapersColors2[index],
                                      wallpapersViews[index],
                                      wallpapersResolution[index],
                                      wallpapersUrl[index],
                                      wallpapersCreatedAt[index],
                                      wallpapersFav[index],
                                      wallpapersSize[index]);
                                },
                              ),
                            );
                          },
                          onDoubleTap: () {
                            if (liked.contains(wallpapersLinks[index])) {
                              liked.remove(wallpapersLinks[index]);
                              final snackBar = SnackBar(
                                content:
                                    Text('Wallpaper removed from favorites!'),
                                duration: Duration(milliseconds: 2000),
                              );
                              Scaffold.of(context).showSnackBar(snackBar);
                              deleteData2(wallpapersId[index]);
                              flareControls2[index].play("dislike");
                            } else {
                              // print("Like");
                              final snackBar = SnackBar(
                                content: Text('Wallpaper added to favorites!'),
                                duration: Duration(milliseconds: 2000),
                              );
                              Scaffold.of(context).showSnackBar(snackBar);
                              liked.add(wallpapersLinks[index]);
                              createRecord2(
                                  wallpapersId[index],
                                  wallpapersLinks[index],
                                  wallpapersThumbs[index],
                                  wallpapersColors[index],
                                  wallpapersColors2[index],
                                  wallpapersViews[index],
                                  wallpapersResolution[index],
                                  wallpapersCreatedAt[index],
                                  wallpapersFav[index],
                                  wallpapersSize[index]);
                              flareControls[index].play("like");
                            }

                            // print(liked.toString());
                          },
                        );
                      }),
                )),
          )
        : Container(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image(
                    image: DynamicTheme.of(context).data.primaryColor ==
                            Color(0xFFFFFFFF)
                        ? AssetImage("assets/images/loadingsw.png")
                        : DynamicTheme.of(context).data.primaryColor ==
                                Color(0xFF272727)
                            ? AssetImage("assets/images/loadingdb.png")
                            : DynamicTheme.of(context).data.primaryColor ==
                                    Color(0xFF000000)
                                ? AssetImage("assets/images/loadingab.png")
                                : DynamicTheme.of(context).data.primaryColor ==
                                        Color(0xFF263238)
                                    ? AssetImage("assets/images/loadingcd.png")
                                    : AssetImage("assets/images/loadingmc.png"),
                    height: 600.h,
                    width: 600.w,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Loading",
                      style: GoogleFonts.raleway(
                          fontSize: 30,
                          color: DynamicTheme.of(context)
                              .data
                              .secondaryHeaderColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    "Sit Back and wait a few seconds\nas your favourite wallpapers are\nloading.",
                    style: GoogleFonts.raleway(
                        fontSize: 16,
                        color:
                            DynamicTheme.of(context).data.secondaryHeaderColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
  }

  void createRecord(
      String id,
      String url,
      String thumb,
      String color,
      String color2,
      String views,
      String resolution,
      String created,
      String fav,
      String size) {
    databaseReference.child(id.toString()).set({
      "id": id,
      "url": url,
      "thumb": thumb,
      "color": color,
      "color2": color2,
      "views": views,
      "resolution": resolution,
      "created": created,
      "fav": fav,
      "size": size
    });
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
    await databaseReference2
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
    print('You fav');
  }

  void getData() {
    databaseReference.once().then((DataSnapshot snapshot) {});
  }

  void getData2() {
    databaseReference2
        .collection("users")
        .document(userId)
        .collection("images")
        .getDocuments()
        .then((QuerySnapshot snapshot) {
      snapshot.documents.forEach((f) => print('${f.data}}'));
    });
  }

  void deleteData(String id) {
    databaseReference.child(id.toString()).remove();
  }

  void deleteData2(String id) {
    try {
      databaseReference2
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
