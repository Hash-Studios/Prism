import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallpapers_app/display.dart';
import 'package:image_gallery/image_gallery.dart';

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
  final Color loadingTextColor = Color(0xFF000000);
  final Color bgColor = Color(0xFFFFFFFF);

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
            color: bgColor,
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
                                tag: allNameList[index],
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
                    // onTap: () {
                    //   Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //       builder: (context) {
                    //         return Display(
                    //             data[index]["url"],
                    //             data[index]["thumb"],
                    //             data[index]["color"],
                    //             data[index]["color2"],
                    //             data[index]["views"],
                    //             data[index]["resolution"],
                    //             "https://whvn.cc/${data[index]["id"]}",
                    //             data[index]["created"],
                    //             data[index]["fav"]);
                    //       },
                    //     ),
                    //   );
                    // },
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
                    "Download some awesome\n wallpapers to add them here.",
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
