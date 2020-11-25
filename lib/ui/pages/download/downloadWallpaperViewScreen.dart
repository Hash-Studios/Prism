import 'dart:io';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/wallpapers/clockOverlay.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DownloadWallpaperScreen extends StatefulWidget {
  final List arguments;
  const DownloadWallpaperScreen({@required this.arguments});
  @override
  _DownloadWallpaperScreenState createState() =>
      _DownloadWallpaperScreenState();
}

class _DownloadWallpaperScreenState extends State<DownloadWallpaperScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  AnimationController shakeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String provider;
  File file;

  @override
  void initState() {
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    super.initState();
    provider = widget.arguments[0] as String;
    file = widget.arguments[1] as File;
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation = Tween(begin: 0.0, end: 48.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        resizeToAvoidBottomPadding: false,
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).primaryColor,
        body: Stack(
          children: <Widget>[
            AnimatedBuilder(
                animation: offsetAnimation,
                builder: (buildContext, child) {
                  if (offsetAnimation.value < 0.0) {
                    debugPrint('${offsetAnimation.value + 8.0}');
                  }
                  return GestureDetector(
                    onLongPress: () {
                      HapticFeedback.vibrate();
                      shakeController.forward(from: 0.0);
                    },
                    onTap: () {
                      HapticFeedback.vibrate();
                      shakeController.forward(from: 0.0);
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(
                          vertical: offsetAnimation.value * 1.25,
                          horizontal: offsetAnimation.value / 2),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(offsetAnimation.value),
                        image: DecorationImage(
                          image: FileImage(file),
                          fit: BoxFit.cover,
                        ),
                      ),
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width,
                    ),
                  );
                }),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SetWallpaperButton(colorChanged: false, url: file.path),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: () {
                    navStack.removeLast();
                    debugPrint(navStack.toString());
                    Navigator.pop(context);
                  },
                  color: Theme.of(context).accentColor,
                  icon: const Icon(
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
                    final link = file.path;
                    Navigator.push(
                        context,
                        PageRouteBuilder(
                            transitionDuration:
                                const Duration(milliseconds: 300),
                            pageBuilder:
                                (context, animation, secondaryAnimation) {
                              animation = Tween(begin: 0.0, end: 1.0)
                                  .animate(animation);
                              return FadeTransition(
                                  opacity: animation,
                                  child: ClockOverlay(
                                    colorChanged: false,
                                    accent: null,
                                    link: link,
                                    file: true,
                                  ));
                            },
                            fullscreenDialog: true,
                            opaque: false));
                  },
                  color: Theme.of(context).accentColor,
                  icon: const Icon(
                    JamIcons.clock,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
