import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Wallpapers extends StatefulWidget {
  @override
  _WallpapersState createState() => _WallpapersState();
}

class _WallpapersState extends State<Wallpapers> {
  Future<Null> refreshList() async {
    refreshKey.currentState?.show(atTop: false);
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      items = List.generate(
          20, (number) => "https://picsum.photos/id/${number + 5}/300/400");
    });

    return null;
  }

  ScrollController controller;
  List<String> items =
      List.generate(20, (number) => "https://picsum.photos/id/$number/300/400");
  var refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
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
    if (controller.position.extentAfter < 200) {
      setState(() {
        items.addAll(new List.generate(
            10, (number) => "https://picsum.photos/id/${number + 40}/300/400"));
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
                      elevation: 8.0,
                      semanticContainer: true,
                      margin: EdgeInsets.all(6),
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
                          title: new Column(
                            children: <Widget>[
                              new Text("GridView"),
                              new Icon(
                                Icons.favorite,
                                color: Colors.green,
                              ),
                            ],
                          ),
                          content: new Text("Selected Item $index"),
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
