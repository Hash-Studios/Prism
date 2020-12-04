import 'dart:io';

import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/core/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:Prism/main.dart' as main;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Prism/theme/config.dart' as config;

class BottomBar extends StatefulWidget {
  final Widget child;
  const BottomBar({
    this.child,
    Key key,
  }) : super(key: key);

  @override
  _BottomBarState createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar>
    with SingleTickerProviderStateMixin {
  ScrollController scrollBottomBarController = ScrollController();
  AnimationController _controller;
  Animation<Offset> _offsetAnimation;
  bool isScrollingDown = false;
  bool isOnTop = true;

  @override
  void initState() {
    myScroll();
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 2),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ))
      ..addListener(() {
        setState(() {});
      });
  }

  void showBottomBar() {
    setState(() {
      _controller.reverse();
    });
  }

  void hideBottomBar() {
    setState(() {
      _controller.forward();
    });
  }

  Future<void> myScroll() async {
    scrollBottomBarController.addListener(() {
      if (scrollBottomBarController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (!isScrollingDown) {
          isScrollingDown = true;
          isOnTop = false;
          hideBottomBar();
        }
      }
      if (scrollBottomBarController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (isScrollingDown) {
          isScrollingDown = false;
          isOnTop = true;
          showBottomBar();
        }
      }
    });
  }

  @override
  void dispose() {
    scrollBottomBarController.removeListener(() {});
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomCenter,
      children: [
        InheritedDataProvider(
          scrollController: scrollBottomBarController,
          child: widget.child,
        ),
        Positioned(
          bottom: 10,
          child: SlideTransition(
            position: _offsetAnimation,
            child: BottomNavBar(),
          ),
        ),
        isOnTop == true
            ? Container()
            : Positioned(
                right: 10,
                bottom: 10,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    scrollBottomBarController
                        .animateTo(
                            scrollBottomBarController.position.minScrollExtent,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeIn)
                        .then((value) {
                      setState(() {
                        isOnTop = true;
                        isScrollingDown = false;
                      });
                      showBottomBar();
                    });
                  },
                  child: const Icon(JamIcons.arrow_up),
                ),
              )
      ],
    );
  }
}

class BottomNavBar extends StatefulWidget {
  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with SingleTickerProviderStateMixin {
  AnimationController _controller2;
  Animation<double> _paddingAnimation;
  bool isLoggedin = false;
  @override
  void initState() {
    checkSignIn();
    super.initState();
    _controller2 = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _paddingAnimation = Tween(
      begin: 18.0,
      end: 20.0,
    ).animate(CurvedAnimation(
      parent: _controller2,
      curve: Curves.easeOutCubic,
    ))
      ..addListener(() {
        setState(() {});
      });
    _controller2.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller2.dispose();
    super.dispose();
  }

  Future<void> checkSignIn() async {
    setState(() {
      isLoggedin = main.prefs.get("isLoggedin") as bool;
    });
  }

  void showGooglePopUp(Function func) {
    debugPrint(isLoggedin.toString());
    if (isLoggedin == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    checkSignIn();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(500),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 0, 12),
              child: IconButton(
                tooltip: 'Home',
                padding: const EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Home" ? 9 : 0,
                    ),
                    Icon(JamIcons.home_f, color: Theme.of(context).accentColor),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Home"
                            ? config.Colors().mainAccentColor(1) == Colors.black
                                ? Colors.white
                                : config.Colors().mainAccentColor(1)
                            : Theme.of(context).accentColor,
                      ),
                      margin: navStack.last == "Home"
                          ? const EdgeInsets.all(3)
                          : const EdgeInsets.all(0),
                      width:
                          navStack.last == "Home" ? _paddingAnimation.value : 0,
                      height: navStack.last == "Home" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  navStack.last == "Home"
                      ? debugPrint("Currently on Home")
                      : Navigator.of(context).popUntil((route) {
                          if (navStack.last != "Home") {
                            navStack.removeLast();
                            debugPrint(navStack.toString());
                            return false;
                          } else {
                            debugPrint(navStack.toString());
                            return true;
                          }
                        });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                tooltip: 'Search',
                padding: const EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Search" ? 9 : 0,
                    ),
                    Icon(JamIcons.search, color: Theme.of(context).accentColor),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Search"
                            ? config.Colors().mainAccentColor(1) == Colors.black
                                ? Colors.white
                                : config.Colors().mainAccentColor(1)
                            : Theme.of(context).accentColor,
                      ),
                      margin: navStack.last == "Search"
                          ? const EdgeInsets.all(3)
                          : const EdgeInsets.all(0),
                      width: navStack.last == "Search"
                          ? _paddingAnimation.value
                          : 0,
                      height: navStack.last == "Search" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  navStack.last == "Search"
                      ? debugPrint("Currently on Search")
                      : navStack.last == "Home"
                          ? Navigator.of(context).pushNamed(searchRoute)
                          : Navigator.of(context).pushNamed(searchRoute);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(
                      color: config.Colors().mainAccentColor(1) == Colors.black
                          ? Colors.white
                          : config.Colors().mainAccentColor(1),
                      width: config.Colors().mainAccentColor(1) == Colors.black
                          ? 1
                          : 0,
                    ),
                    color: config.Colors().mainAccentColor(1),
                    borderRadius: BorderRadius.circular(500)),
                child: IconButton(
                  tooltip: 'Upload',
                  padding: const EdgeInsets.all(0),
                  icon: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        height: navStack.last == "Add" ? 9 : 0,
                      ),
                      Icon(JamIcons.plus, color: Theme.of(context).accentColor),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(500),
                          color: navStack.last == "Add"
                              ? config.Colors().mainAccentColor(1) ==
                                      Colors.black
                                  ? Colors.white
                                  : config.Colors().mainAccentColor(1)
                              : Theme.of(context).accentColor,
                        ),
                        margin: navStack.last == "Add"
                            ? const EdgeInsets.all(3)
                            : const EdgeInsets.all(0),
                        width: navStack.last == "Add"
                            ? _paddingAnimation.value
                            : 0,
                        height: navStack.last == "Add" ? 3 : 0,
                      )
                    ],
                  ),
                  onPressed: () {
                    showGooglePopUp(() {
                      showModalBottomSheet(
                        isScrollControlled: true,
                        context: context,
                        builder: (context) => const UploadBottomPanel(),
                      );
                    });
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                tooltip: 'Setups',
                padding: const EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Setups" ? 9 : 0,
                    ),
                    Icon(JamIcons.instant_picture_f,
                        color: Theme.of(context).accentColor),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Setups"
                            ? config.Colors().mainAccentColor(1) == Colors.black
                                ? Colors.white
                                : config.Colors().mainAccentColor(1)
                            : Theme.of(context).accentColor,
                      ),
                      margin: navStack.last == "Setups"
                          ? const EdgeInsets.all(3)
                          : const EdgeInsets.all(0),
                      width: navStack.last == "Setups"
                          ? _paddingAnimation.value
                          : 0,
                      height: navStack.last == "Setups" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  // showGooglePopUp(() {
                  navStack.last == "Setups"
                      ? debugPrint("Currently on Setups")
                      : navStack.last == "Home"
                          ? Navigator.of(context).pushNamed(setupRoute)
                          : Navigator.of(context).pushNamed(setupRoute);
                  // });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 20, 12),
              child: IconButton(
                tooltip: 'Settings',
                padding: const EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Profile" ? 9 : 0,
                    ),
                    main.prefs.get("isLoggedin") == true
                        ? Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(500),
                                color: Theme.of(context).accentColor),
                            child: Icon(JamIcons.user_circle,
                                color: Theme.of(context).primaryColor),
                          )
                        : Icon(JamIcons.cog_f,
                            color: Theme.of(context).accentColor),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Profile"
                            ? config.Colors().mainAccentColor(1) == Colors.black
                                ? Colors.white
                                : config.Colors().mainAccentColor(1)
                            : Theme.of(context).accentColor,
                      ),
                      margin: navStack.last == "Profile"
                          ? const EdgeInsets.all(3)
                          : const EdgeInsets.all(0),
                      width: navStack.last == "Profile"
                          ? _paddingAnimation.value
                          : 0,
                      height: navStack.last == "Profile" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  if (navStack.last == "Profile") {
                    debugPrint("Currently on Profile");
                  } else {
                    if (navStack.last == "Home") {
                      Navigator.of(context).pushNamed(profileRoute);
                    } else {
                      Navigator.of(context).popUntil((route) {
                        if (navStack.last != "Home" &&
                            navStack.last != "Profile") {
                          navStack.removeLast();
                          debugPrint(navStack.toString());
                          return false;
                        } else {
                          debugPrint(navStack.toString());
                          return true;
                        }
                      });
                      if ((navStack.last == "Home") == true) {
                        Navigator.of(context).pushNamed(profileRoute);
                      }
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadBottomPanel extends StatefulWidget {
  const UploadBottomPanel({
    Key key,
  }) : super(key: key);

  @override
  _UploadBottomPanelState createState() => _UploadBottomPanelState();
}

class _UploadBottomPanelState extends State<UploadBottomPanel> {
  File _wallpaper;
  final picker = ImagePicker();
  @override
  void initState() {
    super.initState();
  }

  Future getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _wallpaper = File(pickedFile.path);
      });
      Navigator.pop(context);
      Future.delayed(const Duration()).then((value) =>
          Navigator.pushNamed(context, editWallRoute, arguments: [_wallpaper]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Container(
      height: MediaQuery.of(context).size.height / 1.5 > 500
          ? MediaQuery.of(context).size.height / 1.5
          : 500,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 5,
                  width: 30,
                  decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(500)),
                ),
              )
            ],
          ),
          const Spacer(),
          Text(
            "Upload",
            style: Theme.of(context).textTheme.headline2,
          ),
          const Spacer(flex: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () async {
                        await getImage();
                      },
                      child: Container(
                        width: width / 2 - 20,
                        height: width / 2 / 0.6625,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: width / 2 - 14,
                              height: width / 2 / 0.6625,
                              decoration: BoxDecoration(
                                color: config.Colors()
                                    .mainAccentColor(1)
                                    .withOpacity(0.2),
                                border: Border.all(
                                    color: config.Colors().mainAccentColor(1),
                                    width: 3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                    opacity: 1,
                                    child: Image.asset(
                                      'assets/images/wallpaper.jpg',
                                      fit: BoxFit.cover,
                                    )),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 60.0),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            config.Colors().mainAccentColor(1),
                                      ),
                                      color: config.Colors()
                                          .mainAccentColor(1)
                                          .withOpacity(0.2),
                                      shape: BoxShape.circle),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Icon(
                                      JamIcons.plus,
                                      color: config.Colors().mainAccentColor(1),
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    "Wallpapers",
                    style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.bold),
                  )
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Future.delayed(const Duration()).then((value) =>
                            Navigator.pushNamed(context, setupGuidelinesRoute));
                      },
                      child: Container(
                        width: width / 2 - 20,
                        height: width / 2 / 0.6625,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: width / 2 - 14,
                              height: width / 2 / 0.6625,
                              decoration: BoxDecoration(
                                color: config.Colors()
                                    .mainAccentColor(1)
                                    .withOpacity(0.2),
                                border: Border.all(
                                    color: config.Colors().mainAccentColor(1),
                                    width: 3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                    opacity: 1,
                                    child: Image.asset(
                                      'assets/images/setup.jpg',
                                      fit: BoxFit.cover,
                                    )),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 60.0),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            config.Colors().mainAccentColor(1),
                                      ),
                                      color: config.Colors()
                                          .mainAccentColor(1)
                                          .withOpacity(0.2),
                                      shape: BoxShape.circle),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Icon(
                                      JamIcons.plus,
                                      color: config.Colors().mainAccentColor(1),
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    "Setups",
                    style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).accentColor,
                        fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                "Please only upload high-quaity original wallpapers and setups. Please do not upload wallpapers from other apps. You can also report wallpapers or setups by clicking the copyright button after opening them.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
