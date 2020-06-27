import 'dart:collection';
import 'dart:io';

import 'package:Prism/router.dart';
import 'package:Prism/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class DownloadScreen extends StatefulWidget {
  @override
  _DownloadScreenState createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  Future<bool> onWillPop() async {
    String route = currentRoute;
    currentRoute = previousRoute;
    previousRoute = route;
    print(currentRoute);
    return true;
  }

  bool dataFetched = false;
  Map<dynamic, dynamic> allImageInfo = HashMap();
  List files = List();
  ScrollController controller;
  var refreshDownloadKey = GlobalKey<RefreshIndicatorState>();
  @override
  void initState() {
    super.initState();
    dataFetched = false;
    files = [];
    readData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String> get localfile async {
    String path = 'storage/emulated/0/';
    return '$path/Prism';
  }

  Future<void> readData() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    final file = await localfile;
    files = Directory(file).listSync();

    if (files.length == 0) {
      setState(() {
        dataFetched = false;
      });
    } else {
      setState(() {
        dataFetched = true;
      });
    }
  }

  Future<Null> refreshList() async {
    refreshDownloadKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    setState(() {
      files = [];
      dataFetched = false;
    });
    readData();

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: PreferredSize(
          child: HeadingChipBar(
            current: "Downloads",
          ),
          preferredSize: Size(double.infinity, 55),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: SafeArea(
          child: RefreshIndicator(
            backgroundColor: Theme.of(context).primaryColor,
            key: refreshDownloadKey,
            onRefresh: refreshList,
            child: dataFetched
                ? Container(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                      itemCount: files.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent:
                              MediaQuery.of(context).orientation ==
                                      Orientation.portrait
                                  ? 300
                                  : 250,
                          childAspectRatio: 0.830,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8),
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                          child: Container(
                            decoration: files.length == 0
                                ? BoxDecoration(
                                    color: Theme.of(context)
                                        .accentColor
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  )
                                : BoxDecoration(
                                    color: Theme.of(context)
                                        .accentColor
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    image: DecorationImage(
                                        image: FileImage(files[index]),
                                        fit: BoxFit.cover)),
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, DownloadWallpaperRoute,
                                arguments: ["Downloads", files[index]]);
                          },
                        );
                      },
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: Provider.of<ThemeModel>(context, listen: false)
                                    .returnTheme() ==
                                ThemeType.Dark
                            ? SvgPicture.asset(
                                "assets/images/downloads dark.svg",
                              )
                            : SvgPicture.asset(
                                "assets/images/downloads light.svg",
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      )
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
