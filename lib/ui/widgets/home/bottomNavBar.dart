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
    ));
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

class _BottomNavBarState extends State<BottomNavBar> {
  bool isLoggedin = false;
  @override
  void initState() {
    checkSignIn();
    super.initState();
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
                    Icon(JamIcons.home_f,
                        color:
                            //  currentRoute == "Home"
                            //     ? Color(0xFFE57697)
                            //     :
                            Theme.of(context).accentColor),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: currentRoute == "Home"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      curve: Curves.fastOutSlowIn,
                      margin: currentRoute == "Home"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: currentRoute == "Home" ? 20 : 0,
                      height: currentRoute == "Home" ? 4 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  currentRoute == "Home"
                      ? print("Currently on Home")
                      : Navigator.of(context)
                          .pushNamedAndRemoveUntil(HomeRoute, (route) => false);
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
                    Icon(JamIcons.search,
                        color:
                            // currentRoute == "Search"
                            //     ? Color(0xFFE57697)
                            //     :
                            Theme.of(context).accentColor),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: currentRoute == "Search"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      curve: Curves.fastOutSlowIn,
                      margin: currentRoute == "Search"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: currentRoute == "Search" ? 20 : 0,
                      height: currentRoute == "Search" ? 4 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  currentRoute == "Search"
                      ? print("Currently on Search")
                      : currentRoute == "Home"
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
                    Icon(JamIcons.heart_f,
                        color:
                            //  currentRoute == "Favourites"
                            //     ? Color(0xFFE57697)
                            //     :
                            Theme.of(context).accentColor),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: currentRoute == "Favourites"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      curve: Curves.fastOutSlowIn,
                      margin: currentRoute == "Favourites"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: currentRoute == "Favourites" ? 20 : 0,
                      height: currentRoute == "Favourites" ? 4 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  showGooglePopUp(() {
                    currentRoute == "Favourites"
                        ? print("Currently on Favourites")
                        : currentRoute == "Home"
                            ? Navigator.of(context).pushNamed(FavRoute)
                            : Navigator.of(context).pushNamed(FavRoute);
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
                padding: EdgeInsets.all(0),
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(500),
                          color:
                              //  currentRoute == "Profile"
                              //     ? Color(0xFFE57697)
                              //     :
                              Theme.of(context).accentColor),
                      child: Icon(JamIcons.user_circle,
                          color: Theme.of(context).primaryColor),
                    ),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 3000),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: currentRoute == "Profile"
                            ? Color(0xFFE57697)
                            : Theme.of(context).accentColor,
                      ),
                      curve: Curves.fastOutSlowIn,
                      margin: currentRoute == "Profile"
                          ? EdgeInsets.all(3)
                          : EdgeInsets.all(0),
                      width: currentRoute == "Profile" ? 20 : 0,
                      height: currentRoute == "Profile" ? 4 : 0,
                    )
                  ],
                ),
                onPressed: () {
                  currentRoute == "Profile"
                      ? print("Currently on Profile")
                      : currentRoute == "Home"
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
