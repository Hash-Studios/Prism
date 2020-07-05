import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:Prism/main.dart' as main;

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
          hideBottomBar();
        }
      }
      if (scrollBottomBarController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (isScrollingDown) {
          isScrollingDown = false;
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
      isLoggedin = main.prefs.getBool("isLoggedin");
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
                      : Navigator.of(context)
                          .pushNamedAndRemoveUntil(HomeRoute, (route) => false);
                  // navStack.last == "Home" ? print("") : navStack = ["Home"];
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
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
              child: IconButton(
                padding: EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Favourites" ? 9 : 0,
                    ),
                    Icon(JamIcons.heart_f,
                        color:
                            //  navStack.last == "Favourites"
                            //     ? Color(0xFFE57697)
                            //     :
                            Theme.of(context).accentColor),
                    Container(
                      // duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: navStack.last == "Favourites"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      // curve: Curves.fastOutSlowIn,
                      margin: navStack.last == "Favourites"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: navStack.last == "Favourites"
                          ? _paddingAnimation.value
                          : 0,
                      height: navStack.last == "Favourites" ? 3 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  showGooglePopUp(() {
                    navStack.last == "Favourites"
                        ? print("Currently on Favourites")
                        : navStack.last == "Home"
                            ? Navigator.of(context).pushNamed(FavRoute)
                            : Navigator.of(context).pushNamed(FavRoute);
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                padding: EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: navStack.last == "Favourites" ? 9 : 0,
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
                  navStack.last == "Setups"
                      ? print("Currently on Setups")
                      : navStack.last == "Home"
                          ? Navigator.of(context).pushNamed(SetupRoute)
                          : Navigator.of(context).pushNamed(SetupRoute);
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

extension NavigatorStateExtension on NavigatorState {
  void pushNamedIfNotCurrent(String routeName, {Object arguments}) {
    if (!isCurrent(routeName)) {
      pushNamed(routeName, arguments: arguments);
    }
  }

  bool isCurrent(String routeName) {
    bool isCurrent = false;
    popUntil((route) {
      if (route.settings.name == routeName) {
        isCurrent = true;
      }
      return true;
    });
    return isCurrent;
  }
}
