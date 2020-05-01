import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallpapers_app/display2.dart';
import 'package:image_gallery/image_gallery.dart';
import 'package:dynamic_theme/dynamic_theme.dart';

class Downloads extends StatefulWidget {
  int width;
  int height;
  Downloads(this.width, this.height);
  @override
  _DownloadsState createState() => _DownloadsState();
}

class _DownloadsState extends State<Downloads> {
  bool dataFetched = false;
  Map<dynamic, dynamic> allImageInfo = new HashMap();
  List allImage = new List();
  List allNameList = new List();

  Future<void> loadImageList() async {
    Map<dynamic, dynamic> allImageTemp;
    allImageTemp = await FlutterGallaryPlugin.getAllImages;

    setState(() {
      for (int i = 0; i < allImageTemp['URIList'].length; i++) {
        if (allImageTemp['URIList'][i].toString().contains("wallhaven")) {
          this.allImage.add(allImageTemp['URIList'][i].toString());
          this.allNameList.add(allImageTemp['DISPLAY_NAME'][i].toString());
        }
      }
      // this.allImage = allImageTemp['URIList'] as List;
      // this.allNameList = allImageTemp['DISPLAY_NAME'] as List;
    });

    setState(() {
      dataFetched = true;
    });
    print(this.allImage.length);
    print(this.allImage);
    print(this.allNameList);
  }

  @override
  void initState() {
    super.initState();
    dataFetched = false;
    loadImageList();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // List data = [];
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);

    return dataFetched
        ? new Container(
            color: DynamicTheme.of(context).data.primaryColor,
            child: Scrollbar(
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
                itemCount: allImage.length,
                gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(
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
                                Radius.circular(24),
                              ),
                            ),
                            elevation: 0.0,
                            semanticContainer: true,
                            margin: EdgeInsets.fromLTRB(4, 4, 4, 4),
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            child: new Container(
                              child: new Hero(
                                tag: allImage[index],
                                child: Image(
                                  image: FileImage(
                                    File(
                                      allImage[index].toString(),
                                    ),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
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
                            return Display2(allImage[index].toString());
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          )
        : Container(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image(
                    image:DynamicTheme.of(context).data.primaryColor ==
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
                      "Oops!",
                      style: GoogleFonts.raleway(
                          fontSize: 30, color: DynamicTheme.of(context).data.secondaryHeaderColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    "Download some awesome\n wallpapers to add them here.",
                    style: GoogleFonts.raleway(
                        fontSize: 16, color: DynamicTheme.of(context).data.secondaryHeaderColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
  }
}
