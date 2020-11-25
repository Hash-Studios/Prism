import 'dart:collection';
import 'dart:io';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;

class DownloadScreen extends StatefulWidget {
  @override
  _DownloadScreenState createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  bool dataFetched = false;
  Map<dynamic, dynamic> allImageInfo = HashMap();
  List<FileSystemEntity> files = [];
  ScrollController controller;
  GlobalKey<RefreshIndicatorState> refreshDownloadKey =
      GlobalKey<RefreshIndicatorState>();
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
    const String path = 'storage/emulated/0/';
    return '${path}Prism';
  }

  Future<String> get newLocalfile async {
    const String path = 'storage/emulated/0/';
    return '${path}Pictures/Prism';
  }

  Future<void> readData() async {
    final status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    final file = await localfile;
    final fileNew = await newLocalfile;
    try {
      files = Directory(fileNew).listSync();
    } catch (e) {
      debugPrint(e.toString());
    }
    try {
      files.addAll(Directory(file).listSync());
    } catch (e) {
      debugPrint(e.toString());
    }
    if (files.isEmpty) {
      setState(() {
        dataFetched = false;
      });
    } else {
      setState(() {
        dataFetched = true;
      });
    }
  }

  // ignore: prefer_void_to_null
  Future<Null> refreshList() async {
    refreshDownloadKey.currentState?.show();
    await Future.delayed(const Duration(milliseconds: 500));
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
        appBar: const PreferredSize(
          preferredSize: Size(double.infinity, 55),
          child: HeadingChipBar(
            current: "Downloads",
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: SafeArea(
          child: RefreshIndicator(
            backgroundColor: Theme.of(context).primaryColor,
            key: refreshDownloadKey,
            onRefresh: refreshList,
            child: dataFetched
                ? GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                    itemCount: files.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            MediaQuery.of(context).orientation ==
                                    Orientation.portrait
                                ? 300
                                : 250,
                        childAspectRatio: 0.6625,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8),
                    itemBuilder: (BuildContext context, int index) {
                      return Stack(
                        children: [
                          Container(
                            decoration: files.isEmpty
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
                                        image: FileImage(files[index] as File),
                                        fit: BoxFit.cover)),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                splashColor: Theme.of(context)
                                    .accentColor
                                    .withOpacity(0.3),
                                highlightColor: Theme.of(context)
                                    .accentColor
                                    .withOpacity(0.1),
                                onTap: () {
                                  Navigator.pushNamed(
                                      context, downloadWallpaperRoute,
                                      arguments: ["Downloads", files[index]]);
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: Provider.of<ThemeModel>(context, listen: false)
                                    .returnThemeType() ==
                                "Dark"
                            ? SvgPicture.string(
                                downloadsDark
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        main.prefs
                                            .get("mainAccentColor")
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
                              )
                            : SvgPicture.string(
                                downloadsLight
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        main.prefs
                                            .get("mainAccentColor")
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
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
