import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wallpapers_app/wallheaven.dart';

class Wallpapers extends StatefulWidget {
  @override
  _WallpapersState createState() => _WallpapersState();
}

class _WallpapersState extends State<Wallpapers> {
  String query = "";
  bool fetchedData = false;
  List wallpapersLinks = [];
  List wallpapersThumbs = [];
  List wallpapersColors = [];
  WallData wallheaven = WallData();

  void getwalls(String query) async {
    fetchedData = false;
    Map data = await wallheaven.getData(query);
    wallpapersLinks = data["links"];
    wallpapersThumbs = data["thumbs"];
    wallpapersColors = data["colors"];
    fetchedData = true;
  }

  Future<Null> refreshList() async {
    refreshKey.currentState?.show(atTop: false);
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      items = List.generate(
          20, (number) => "https://picsum.photos/id/${number + 5}/600/800");
    });

    return null;
  }

  ScrollController controller;
  List<String> items =
      List.generate(20, (number) => "https://picsum.photos/id/$number/600/800");
  var refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    getwalls(query);
    controller = new ScrollController()..addListener(_scrollListener);
    // ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    // print(controller.position.extentAfter);
    if (controller.position.extentAfter < 500) {
      setState(() {
        items.addAll(new List.generate(
            10, (number) => "https://picsum.photos/id/${number + 40}/600/800"));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refreshList,
      child: new Container(
          color: Colors.white,
          child: Scrollbar(
            child: GridView.builder(
                controller: controller,
                padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                itemCount: items.length,
                gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.75),
                itemBuilder: (BuildContext context, int index) {
                  return new GestureDetector(
                    child: new Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24))),
                      elevation: 2.0,
                      semanticContainer: true,
                      margin: EdgeInsets.fromLTRB(7, 7, 7, 7),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: new Container(
                          child: new FadeInImage(
                        placeholder: CacheImage(
                            "https://via.placeholder.com/300x400.jpg/FFFFFF/FFFFFF"),
                        image: CacheImage(
                          items[index],
                        ),
                        fit: BoxFit.cover,
                      )),
                    ),
                    onTap: () {
                      showDialog(
                        barrierDismissible: false,
                        context: context,
                        child: new AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(24))),
                          title: new Column(
                            children: <Widget>[
                              new Text("Image $index"),
                            ],
                          ),
                          content: new Image(image: CacheImage(items[index])),
                          actions: <Widget>[
                            new FlatButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: new Text("OK"))
                          ],
                        ),
                      );
                    },
                  );
                }),
          )),
    );
  }
}
