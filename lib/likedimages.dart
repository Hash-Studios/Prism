import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallpapers_app/display.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dynamic_theme/dynamic_theme.dart';

class LikedImages extends StatefulWidget {
  int width;
  int height;
  LikedImages(this.width, this.height);
  @override
  _LikedImagesState createState() => _LikedImagesState();
}

class _LikedImagesState extends State<LikedImages> {
  final databaseReference = FirebaseDatabase.instance.reference().child("user");
  List liked = [];
  List<FlareControls> flareControls;
  final Color loadingTextColor = Color(0xFF000000);
  final Color bgColor = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  List data = [];
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
    return FutureBuilder(
        future: databaseReference.once(),
        builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
          if (snapshot.hasData) {
            data = [];
            liked = [];
            flareControls = [];
            Map<dynamic, dynamic> values = {};
            values = snapshot.data.value;
            if (values != null) {
              values.forEach(
                (k, v) => data.add(v),
              );
              values.forEach(
                (k, v) => liked.add(k),
              );
              values.forEach(
                (k, v) => flareControls.add(
                  new FlareControls(),
                ),
              );

              return new Container(
                  color: bgColor,
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
                                            tag: data[index]["url"],
                                            child: Image(
                                              image: CacheImage(
                                                data[index]["thumb"],
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
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return Display(
                                        data[index]["url"],
                                        data[index]["thumb"],
                                        data[index]["color"],
                                        data[index]["color2"],
                                        data[index]["views"],
                                        data[index]["resolution"],
                                        "https://whvn.cc/${data[index]["id"]}",
                                        data[index]["created"],
                                        data[index]["fav"],
                                        data[index]["size"]);
                                  },
                                ),
                              );
                            },
                            onDoubleTap: () {
                              if (liked.contains(data[index]["id"])) {
                                // print("Dislike");
                                liked.remove(data[index]["id"]);
                                deleteData(data[index]["id"]);
                              } else {
                                // print("Like");
                                liked.add(data[index]["id"]);
                                createRecord(
                                    data[index]["id"],
                                    data[index]["url"],
                                    data[index]["thumb"],
                                    data[index]["color"],
                                    data[index]["color2"],
                                    data[index]["views"],
                                    data[index]["resolution"],
                                    data[index]["created"],
                                    data[index]["fav"],
                                    data[index]["size"]);
                              }
                              flareControls[index].play("like");
                              // print(liked.toString());
                            },
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
                        image: AssetImage("assets/images/loading.png"),
                        height: 600.h,
                        width: 600.w,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Oops!",
                          style: GoogleFonts.raleway(
                              fontSize: 30, color: loadingTextColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text(
                        "Double tap some awesome\n wallpapers to add them here.",
                        style: GoogleFonts.raleway(
                            fontSize: 16, color: loadingTextColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
          }
          return Container(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image(
                    image: AssetImage("assets/images/loading.png"),
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
        });
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
      "size": size,
    });
  }

  void getData() {
    databaseReference.once().then((DataSnapshot snapshot) {
      // print('Data : ${snapshot.value}');
    });
  }

  void deleteData(String id) {
    databaseReference.child(id.toString()).remove();
  }
}
