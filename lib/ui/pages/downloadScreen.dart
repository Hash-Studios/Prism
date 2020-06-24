import 'dart:collection';
import 'dart:io';

import 'package:Prism/routing_constants.dart';
import 'package:flutter/material.dart';

class DownloadScreen extends StatefulWidget {
  @override
  _DownloadScreenState createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
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
    return SafeArea(
      child: RefreshIndicator(
        key: refreshDownloadKey,
        onRefresh: refreshList,
        child: Container(
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
            itemCount: files.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    MediaQuery.of(context).orientation == Orientation.portrait
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
                          color:
                              Theme.of(context).accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        )
                      : BoxDecoration(
                          color:
                              Theme.of(context).accentColor.withOpacity(0.12),
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
        ),
      ),
    );
  }
}
