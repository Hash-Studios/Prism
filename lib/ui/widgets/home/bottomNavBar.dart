import 'dart:io';

import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:Prism/main.dart' as main;
import 'package:image_picker/image_picker.dart';

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
  ScrollController scrollBottomBarController = new ScrollController();
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

  void myScroll() async {
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
        isOnTop
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
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeIn)
                        .then((value) {
                      setState(() {
                        isOnTop = true;
                        isScrollingDown = false;
                      });
                      showBottomBar();
                    });
                  },
                  child: Icon(JamIcons.arrow_up),
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

  void checkSignIn() async {
    setState(() {
      isLoggedin = main.prefs.get("isLoggedin");
    });
  }

  void showGooglePopUp(Function func) {
    print(isLoggedin);
    if (!isLoggedin) {
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
              color: Color(0xFF000000).withOpacity(0.25),
              blurRadius: 4,
              offset: Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(500),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          // key: globals.keyBottomBar,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 0, 12),
              child: IconButton(
                padding: EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Home" ? 9 : 0,
                    ),
                    Icon(JamIcons.home_f,
                        color:
                            //  currentRoute == "Home"
                            //     ? Color(0xFFE57697)
                            //     :
                            Theme.of(context).accentColor),
                    Container(
                      // duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Home"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      // curve: Curves.fastOutSlowIn,
                      margin: navStack.last == "Home"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width:
                          navStack.last == "Home" ? _paddingAnimation.value : 0,
                      height: navStack.last == "Home" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  navStack.last == "Home"
                      ? print("Currently on Home")
                      : Navigator.of(context).popUntil((route) {
                          if (navStack.last != "Home") {
                            navStack.removeLast();
                            print(navStack);
                            return false;
                          } else {
                            print(navStack);
                            return true;
                          }
                        });
                  // .pushNamedAndRemoveUntil(HomeRoute, (route) => false);
                  // navStack.last == "Home" ? print("") : navStack = ["Home"];
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                // key: globals.keySearchButton,
                padding: EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Search" ? 9 : 0,
                    ),
                    Icon(JamIcons.search,
                        color:
                            // navStack.last == "Search"
                            //     ? Color(0xFFE57697)
                            //     :
                            Theme.of(context).accentColor),
                    Container(
                      // duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Search"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      // curve: Curves.fastOutSlowIn,
                      margin: navStack.last == "Search"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: navStack.last == "Search"
                          ? _paddingAnimation.value
                          : 0,
                      height: navStack.last == "Search" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  navStack.last == "Search"
                      ? print("Currently on Search")
                      : navStack.last == "Home"
                          ? Navigator.of(context).pushNamed(SearchRoute)
                          : Navigator.of(context).pushNamed(SearchRoute);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: Container(
                decoration: BoxDecoration(
                    color: Color(0xFFE57697),
                    borderRadius: BorderRadius.circular(500)),
                child: IconButton(
                  // key: globals.keyFavButton,
                  padding: EdgeInsets.all(0),
                  icon: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        height: navStack.last == "Add" ? 9 : 0,
                      ),
                      Icon(JamIcons.plus,
                          color:
                              //  navStack.last == "Favourites"
                              //     ? Color(0xFFE57697)
                              //     :
                              Theme.of(context).accentColor),
                      Container(
                        // duration: Duration(milliseconds: 3000),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(500),
                          color: navStack.last == "Add"
                              ? Color(0xFFE57697)
                              : Theme.of(context).accentColor,
                        ),
                        // curve: Curves.fastOutSlowIn,
                        margin: navStack.last == "Add"
                            ? EdgeInsets.all(3)
                            : EdgeInsets.all(0),
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
                        builder: (context) => UploadBottomPanel(),
                      );
                      //   navStack.last == "Add"
                      //       ? print("Currently on Add")
                      //       : navStack.last == "Home"
                      //           ? Navigator.of(context).pushNamed(FavRoute)
                      //           : Navigator.of(context).pushNamed(FavRoute);
                    });
                  },
                ),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
            //   child: IconButton(
            //     // key: globals.keyFavButton,
            //     padding: EdgeInsets.all(0),
            //     icon: Column(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       mainAxisSize: MainAxisSize.min,
            //       children: <Widget>[
            //         Container(
            //           height: navStack.last == "Favourites" ? 9 : 0,
            //         ),
            //         Icon(JamIcons.heart_f,
            //             color:
            //                 //  navStack.last == "Favourites"
            //                 //     ? Color(0xFFE57697)
            //                 //     :
            //                 Theme.of(context).accentColor),
            //         Container(
            //           // duration: Duration(milliseconds: 3000),
            //           decoration: BoxDecoration(
            //             borderRadius: BorderRadius.circular(500),
            //             color: navStack.last == "Favourites"
            //                 ? Color(0xFFE57697)
            //                 : Theme.of(context).accentColor,
            //           ),
            //           // curve: Curves.fastOutSlowIn,
            //           margin: navStack.last == "Favourites"
            //               ? EdgeInsets.all(3)
            //               : EdgeInsets.all(0),
            //           width: navStack.last == "Favourites"
            //               ? _paddingAnimation.value
            //               : 0,
            //           height: navStack.last == "Favourites" ? 3 : 0,
            //         )
            //       ],
            //     ),
            //     onPressed: () {
            //       showGooglePopUp(() {
            //         navStack.last == "Favourites"
            //             ? print("Currently on Favourites")
            //             : navStack.last == "Home"
            //                 ? Navigator.of(context).pushNamed(FavRoute)
            //                 : Navigator.of(context).pushNamed(FavRoute);
            //       });
            //     },
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                padding: EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Setups" ? 9 : 0,
                    ),
                    Icon(JamIcons.instant_picture_f,
                        color:
                            //  navStack.last == "Favourites"
                            //     ? Color(0xFFE57697)
                            //     :
                            Theme.of(context).accentColor),
                    Container(
                      // duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Setups"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      // curve: Curves.fastOutSlowIn,
                      margin: navStack.last == "Setups"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: navStack.last == "Setups"
                          ? _paddingAnimation.value
                          : 0,
                      height: navStack.last == "Setups" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  showGooglePopUp(() {
                    navStack.last == "Setups"
                        ? print("Currently on Setups")
                        : navStack.last == "Home"
                            ? Navigator.of(context).pushNamed(SetupRoute)
                            : Navigator.of(context).pushNamed(SetupRoute);
                  });
                },
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
            //   child: IconButton(
            //     icon: Icon(JamIcons.instant_picture_f,
            //         color: Theme.of(context).accentColor),
            //     onPressed: () {},
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 20, 12),
              child: IconButton(
                // key: globals.keyProfileButton,
                padding: EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Profile" ? 9 : 0,
                    ),
                    Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(500),
                          color:
                              //  navStack.last == "Profile"
                              //     ? Color(0xFFE57697)
                              //     :
                              Theme.of(context).accentColor),
                      child: Icon(JamIcons.user_circle,
                          color: Theme.of(context).primaryColor),
                    ),
                    Container(
                      // duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Profile"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      // curve: Curves.fastOutSlowIn,
                      margin: navStack.last == "Profile"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: navStack.last == "Profile"
                          ? _paddingAnimation.value
                          : 0,
                      height: navStack.last == "Profile" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  navStack.last == "Profile"
                      ? print("Currently on Profile")
                      : navStack.last == "Home"
                          ? Navigator.of(context).pushNamed(ProfileRoute)
                          : Navigator.of(context).pushNamed(ProfileRoute);
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
      Future.delayed(Duration(seconds: 0)).then((value) =>
          Navigator.pushNamed(context, EditWallRoute, arguments: [_wallpaper]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height / 1.4,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.only(
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
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  JamIcons.chevron_down,
                  color: Theme.of(context).accentColor,
                ),
              )
            ],
          ),
          Spacer(),
          Text(
            "Upload a Wallpaper",
            style: Theme.of(context).textTheme.headline2,
          ),
          Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
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
                        width: MediaQuery.of(context).size.width / 2 - 20,
                        height: MediaQuery.of(context).size.width / 2 / 0.6625,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: MediaQuery.of(context).size.width / 2 - 14,
                              height: MediaQuery.of(context).size.width /
                                  2 /
                                  0.6625,
                              decoration: BoxDecoration(
                                color: Color(0xFFE57697).withOpacity(0.2),
                                border: Border.all(
                                    color: Color(0xFFE57697), width: 3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                    opacity: 1,
                                    child: Image.asset(
                                      'assets/images/wallpaper2.jpg',
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
                                          color: Color(0xFFE57697), width: 1),
                                      color: Color(0xFFE57697).withOpacity(0.2),
                                      shape: BoxShape.circle),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Icon(
                                      JamIcons.plus,
                                      color: Color(0xFFE57697),
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
                        color: Color(0xFFE57697),
                        fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ],
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                "Now you can upload your wallpapers, and zip bada boom, in a matter of seconds, they will be live and everyone across the globe can view them.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
