import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/ui/widgets/setups/arrowAnimation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/global/globals.dart' as globals;

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    Key key,
  }) : super(key: key);

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  Future<bool> onWillPop() async {
    navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  final PageController controller = PageController(
    viewportFraction: 0.78,
  );
  Future future;

  @override
  void initState() {
    future = Provider.of<SetupProvider>(context, listen: false).getDataBase();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: BottomBar(
          child: SafeArea(
            top: false,
            child: SetupPage(future: future, controller: controller),
          ),
        ),
      ),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({
    Key key,
    @required this.future,
    @required this.controller,
  }) : super(key: key);

  final Future future;
  final PageController controller;

  @override
  _SetupPageState createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  int pageNumber = 0;
  void showPremiumPopUp(Function func) {
    if (main.prefs.get("isLoggedin") == false ||
        main.prefs.get("isLoggedin") == null) {
      googleSignInPopUp(context, () {
        if (main.prefs.get("premium") == false ||
            main.prefs.get("premium") == null) {
          Navigator.pushNamed(context, premiumRoute);
        } else {
          func();
        }
      });
    } else {
      if (main.prefs.get("premium") == false ||
          main.prefs.get("premium") == null) {
        Navigator.pushNamed(context, premiumRoute);
      } else {
        func();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        Positioned(
          top: 0,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  config.Colors().mainAccentColor(1),
                  Theme.of(context).primaryColor
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 1],
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: MediaQuery.of(context).size.width - 25,
                padding: EdgeInsets.only(left: 25, top: 5 + globals.notchSize),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Text(
                        Provider.of<SetupProvider>(context, listen: false)
                                .setups
                                .isEmpty
                            ? ""
                            : Provider.of<SetupProvider>(context, listen: false)
                                .setups[pageNumber]['name']
                                .toString()
                                .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headline1
                            .copyWith(fontSize: 30),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.12),
          child: FutureBuilder(
              future: widget.future,
              builder: (context, snapshot) {
                if (snapshot == null) {
                  debugPrint("snapshot null");
                  return Center(child: Loader());
                }
                if (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none) {
                  debugPrint("snapshot none, waiting");
                  return Center(child: Loader());
                } else {
                  Future.delayed(const Duration())
                      .then((value) => setState(() {}));
                  return GestureDetector(
                    onTap: () {
                      if (pageNumber >= 5) {
                        showPremiumPopUp(() {
                          Navigator.pushNamed(context, setupViewRoute,
                              arguments: [pageNumber]);
                        });
                      } else {
                        Navigator.pushNamed(context, setupViewRoute,
                            arguments: [pageNumber]);
                      }
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.9,
                      child: PageView.builder(
                        onPageChanged: (value) {
                          setState(() {
                            pageNumber = value;
                          });
                        },
                        controller: widget.controller,
                        itemCount: Provider.of<SetupProvider>(context,
                                    listen: false)
                                .setups
                                .isEmpty
                            ? 1
                            : Provider.of<SetupProvider>(context, listen: false)
                                .setups
                                .length,
                        itemBuilder: (context, index) => Provider.of<
                                    SetupProvider>(context, listen: false)
                                .setups
                                .isEmpty
                            ? Loader()
                            : AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.only(
                                  top: pageNumber == index + 1 ||
                                          pageNumber == index - 1
                                      ? MediaQuery.of(context).size.height *
                                          0.12
                                      : MediaQuery.of(context).size.height *
                                          0.0499,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: CachedNetworkImage(
                                    imageUrl: Provider.of<SetupProvider>(
                                            context,
                                            listen: false)
                                        .setups[index]['image']
                                        .toString(),
                                    imageBuilder: (context, imageProvider) =>
                                        Container(
                                      width:
                                          MediaQuery.of(context).size.height *
                                              0.7 *
                                              (9 / 19.5),
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.7,
                                      decoration: BoxDecoration(
                                        boxShadow: pageNumber == index
                                            ? Provider.of<ThemeModel>(context)
                                                        .returnThemeType() ==
                                                    "Light"
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(.15),
                                                      blurRadius: 38,
                                                      offset:
                                                          const Offset(0, 19),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(.10),
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 15),
                                                    )
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(.7),
                                                      blurRadius: 38,
                                                      offset:
                                                          const Offset(0, 19),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(.6),
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 15),
                                                    )
                                                  ]
                                            : [],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: PremiumBannerSetupOld(
                                        comparator: index < 5,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.7 *
                                                (9 / 19.5),
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.7,
                                            child: Image(
                                                image: imageProvider,
                                                fit: BoxFit.fill),
                                          ),
                                        ),
                                      ),
                                    ),
                                    progressIndicatorBuilder:
                                        (context, url, downloadProgress) =>
                                            Container(
                                      width:
                                          MediaQuery.of(context).size.height *
                                              0.7 *
                                              (9 / 19.5),
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.7,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation(
                                              Provider.of<ThemeModel>(context)
                                                          .currentTheme ==
                                                      kDarkTheme2
                                                  ? config.Colors()
                                                              .mainAccentColor(
                                                                  1) ==
                                                          Colors.black
                                                      ? Theme.of(context)
                                                          .accentColor
                                                      : config.Colors()
                                                          .mainAccentColor(1)
                                                  : config.Colors()
                                                      .mainAccentColor(1),
                                            ),
                                            value: downloadProgress.progress),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Center(
                                      child: Icon(
                                        JamIcons.close_circle_f,
                                        color: Theme.of(context).accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                }
              }),
        ),
        pageNumber == 0
            ? Container()
            : Align(
                alignment: Alignment.centerLeft,
                child: ArrowBounceAnimation(
                  onTap: () {
                    widget.controller.animateToPage(
                        widget.controller.page.toInt() - 1,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.fastOutSlowIn);
                    HapticFeedback.vibrate();
                  },
                  child: Icon(
                    JamIcons.chevron_left,
                    color: Provider.of<ThemeModel>(context).currentTheme ==
                            kDarkTheme2
                        ? config.Colors().mainAccentColor(1) == Colors.black
                            ? Theme.of(context).accentColor
                            : config.Colors().mainAccentColor(1)
                        : config.Colors().mainAccentColor(1),
                  ),
                ),
              ),
        pageNumber ==
                Provider.of<SetupProvider>(context, listen: false)
                        .setups
                        .length -
                    1
            ? Container()
            : Align(
                alignment: Alignment.centerRight,
                child: ArrowBounceAnimation(
                  onTap: () {
                    widget.controller.animateToPage(
                        widget.controller.page.toInt() + 1,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.fastOutSlowIn);
                    HapticFeedback.vibrate();
                  },
                  child: Icon(
                    JamIcons.chevron_right,
                    color: Provider.of<ThemeModel>(context).currentTheme ==
                            kDarkTheme2
                        ? config.Colors().mainAccentColor(1) == Colors.black
                            ? Theme.of(context).accentColor
                            : config.Colors().mainAccentColor(1)
                        : config.Colors().mainAccentColor(1),
                  ),
                ),
              ),
      ],
    );
  }
}
