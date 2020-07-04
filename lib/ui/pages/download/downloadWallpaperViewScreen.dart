import 'dart:io';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/clockOverlay.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DownloadWallpaperScreen extends StatefulWidget {
  final List arguments;
  DownloadWallpaperScreen({@required this.arguments});
  @override
  _DownloadWallpaperScreenState createState() =>
      _DownloadWallpaperScreenState();
}

class _DownloadWallpaperScreenState extends State<DownloadWallpaperScreen> {
  Future<bool> onWillPop() async {
    String route = currentRoute;
    currentRoute = previousRoute;
    previousRoute = route;
    print(currentRoute);
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String provider;
  File file;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]);
    provider = widget.arguments[0];
    file = widget.arguments[1];
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    try {
      return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
          resizeToAvoidBottomPadding: false,
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
                      String route = currentRoute;
                      currentRoute = previousRoute;
                      previousRoute = route;
                      print(currentRoute);
                      Navigator.pop(context);
                    },
                    color: Theme.of(context).accentColor,
                    icon: Icon(
                      JamIcons.chevron_left,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: () {
                      var link = file.path;
                      Navigator.push(
                          context,
                          PageRouteBuilder(
                              transitionDuration: Duration(milliseconds: 300),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) {
                                animation = Tween(begin: 0.0, end: 1.0)
                                    .animate(animation);
                                return FadeTransition(
                                    opacity: animation,
                                    child: ClockOverlay(
                                      link: link,
                                      file: true,
                                    ));
                              },
                              fullscreenDialog: true,
                              opaque: false));
                    },
                    color: Theme.of(context).accentColor,
                    icon: Icon(
                      JamIcons.clock,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    } catch (e) {
      print(e.toString());
      String route = currentRoute;
      currentRoute = previousRoute;
      previousRoute = route;
      print(currentRoute);
      Navigator.pop(context);
      return Container();
    }
  }
}
