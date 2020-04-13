import 'package:flutter/material.dart';
import 'package:cache_image/cache_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Wallpapers extends StatefulWidget {
  @override
  _WallpapersState createState() => _WallpapersState();
}

class _WallpapersState extends State<Wallpapers> {
  @override
  void initState() {
    super.initState();
    // ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
        color: Colors.white,
        child: GridView.builder(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
            itemCount: 10,
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
                      child: new Image(
                    image: CacheImage(
                      "https://picsum.photos/300/400",
                    ),
                    fit: BoxFit.fill,
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
            }));
  }
}
