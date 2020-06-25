import 'dart:io';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/setWallpaperButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DownloadWallpaperScreen extends StatefulWidget {
  final List arguements;
  DownloadWallpaperScreen({@required this.arguements});
  @override
  _DownloadWallpaperScreenState createState() =>
      _DownloadWallpaperScreenState();
}

class _DownloadWallpaperScreenState extends State<DownloadWallpaperScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String provider;
  File file;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    provider = widget.arguements[0];
    file = widget.arguements[1];
    isLoading = true;
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([]);
    try {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).primaryColor,
        body: Stack(
          children: <Widget>[
            Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Image.file(
                file,
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SetWallpaperButton(url: file.path),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  color: Theme.of(context).accentColor,
                  icon: Icon(
                    JamIcons.chevron_left,
                  ),
                ),
              ),
            )
          ],
        ),
      );
    } catch (e) {
      print(e.toString());
      Navigator.pop(context);
      return Container();
    }
  }
}
