import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/setups/arrowAnimation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;

class SetupScreen extends StatefulWidget {
  SetupScreen({
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
    initialPage: 0,
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
    if (!main.prefs.get("premium")) {
      Navigator.pushNamed(context, premiumRoute);
    } else {
      func();
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
                stops: [0, 1],
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: MediaQuery.of(context).size.width - 25,
                padding: EdgeInsets.only(left: 25, top: 25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      main.prefs.get("premium")
                          ? Provider.of<SetupProvider>(context, listen: false)
                                      .setups
                                      .length ==
                                  0
                              ? ""
                              : Provider.of<SetupProvider>(context,
                                      listen: false)
                                  .setups[pageNumber]['name']
                                  .toString()
                                  .toUpperCase()
                          : (pageNumber == 5)
                              ? "BUY PREMIUM"
                              : Provider.of<SetupProvider>(context,
                                              listen: false)
                                          .setups
                                          .length ==
                                      0
                                  ? ""
                                  : Provider.of<SetupProvider>(context,
                                          listen: false)
                                      .setups[pageNumber]['name']
                                      .toString()
                                      .toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .headline1
                          .copyWith(fontSize: 30),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
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
                  Future.delayed(Duration(seconds: 0))
                      .then((value) => setState(() {
                            pageNumber;
                          }));
                  return GestureDetector(
                    onTap: () {
                      if (pageNumber == 5) {
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
                        itemCount: main.prefs.get("premium")
                            ? Provider.of<SetupProvider>(context, listen: false)
                                        .setups
                                        .length ==
                                    0
                                ? 1
                                : Provider.of<SetupProvider>(context,
                                        listen: false)
                                    .setups
                                    .length
                            : 6,
                        itemBuilder: (context, index) => main.prefs
                                .get("premium")
                            ? Provider.of<SetupProvider>(context, listen: false)
                                        .setups
                                        .length ==
                                    0
                                ? Loader()
                                : AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    padding: EdgeInsets.only(
                                      top: pageNumber == index + 1 ||
                                              pageNumber == index - 1
                                          ? MediaQuery.of(context).size.height *
                                              0.1
                                          : MediaQuery.of(context).size.height *
                                              0.0299,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: CachedNetworkImage(
                                        imageUrl: Provider.of<SetupProvider>(
                                                context,
                                                listen: false)
                                            .setups[index]['image'],
                                        imageBuilder:
                                            (context, imageProvider) => Hero(
                                          tag: "CustomHerotag$index",
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.712,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.72,
                                            decoration: BoxDecoration(
                                              boxShadow: pageNumber == index
                                                  ? Provider.of<ThemeModel>(
                                                                  context)
                                                              .currentTheme ==
                                                          kLightTheme
                                                      ? [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    .15),
                                                            blurRadius: 38,
                                                            offset:
                                                                Offset(0, 19),
                                                          ),
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    .10),
                                                            blurRadius: 12,
                                                            offset:
                                                                Offset(0, 15),
                                                          )
                                                        ]
                                                      : [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    .7),
                                                            blurRadius: 38,
                                                            offset:
                                                                Offset(0, 19),
                                                          ),
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    .6),
                                                            blurRadius: 12,
                                                            offset:
                                                                Offset(0, 15),
                                                          )
                                                        ]
                                                  : [],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              image: DecorationImage(
                                                  image: imageProvider,
                                                  fit: BoxFit.fill),
                                            ),
                                          ),
                                        ),
                                        progressIndicatorBuilder:
                                            (context, url, downloadProgress) =>
                                                Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.712,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.72,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                  config.Colors()
                                                      .mainAccentColor(1),
                                                ),
                                                value:
                                                    downloadProgress.progress),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          child: Center(
                                            child: Icon(
                                              JamIcons.close_circle_f,
                                              color:
                                                  Theme.of(context).accentColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                            : (index == 5)
                                ? AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    padding: EdgeInsets.only(
                                      top: pageNumber == index + 1 ||
                                              pageNumber == index - 1
                                          ? MediaQuery.of(context).size.height *
                                              0.1
                                          : MediaQuery.of(context).size.height *
                                              0.0299,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Hero(
                                        tag: "CustomHerotag$index",
                                        child: Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.712,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.72,
                                          decoration: BoxDecoration(
                                            boxShadow: pageNumber == index
                                                ? Provider.of<ThemeModel>(
                                                                context)
                                                            .currentTheme ==
                                                        kLightTheme
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(.15),
                                                          blurRadius: 38,
                                                          offset: Offset(0, 19),
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(.10),
                                                          blurRadius: 12,
                                                          offset: Offset(0, 15),
                                                        )
                                                      ]
                                                    : [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(.7),
                                                          blurRadius: 38,
                                                          offset: Offset(0, 19),
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(.6),
                                                          blurRadius: 12,
                                                          offset: Offset(0, 15),
                                                        )
                                                      ]
                                                : [],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            image: DecorationImage(
                                                image: AssetImage(
                                                    'assets/images/Premium.png'),
                                                fit: BoxFit.fill),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Provider.of<SetupProvider>(context,
                                                listen: false)
                                            .setups
                                            .length ==
                                        0
                                    ? Loader()
                                    : AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
                                        padding: EdgeInsets.only(
                                          top: pageNumber == index + 1 ||
                                                  pageNumber == index - 1
                                              ? MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.1
                                              : MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.0299,
                                        ),
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                Provider.of<SetupProvider>(
                                                        context,
                                                        listen: false)
                                                    .setups[index]['image'],
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    Hero(
                                              tag: "CustomHerotag$index",
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.712,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.72,
                                                decoration: BoxDecoration(
                                                  boxShadow: pageNumber == index
                                                      ? Provider.of<ThemeModel>(
                                                                      context)
                                                                  .currentTheme ==
                                                              kLightTheme
                                                          ? [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .15),
                                                                blurRadius: 38,
                                                                offset: Offset(
                                                                    0, 19),
                                                              ),
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .10),
                                                                blurRadius: 12,
                                                                offset: Offset(
                                                                    0, 15),
                                                              )
                                                            ]
                                                          : [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .7),
                                                                blurRadius: 38,
                                                                offset: Offset(
                                                                    0, 19),
                                                              ),
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .6),
                                                                blurRadius: 12,
                                                                offset: Offset(
                                                                    0, 15),
                                                              )
                                                            ]
                                                      : [],
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  image: DecorationImage(
                                                      image: imageProvider,
                                                      fit: BoxFit.fill),
                                                ),
                                              ),
                                            ),
                                            progressIndicatorBuilder: (context,
                                                    url, downloadProgress) =>
                                                Container(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.712,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.72,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                          config.Colors()
                                                              .mainAccentColor(
                                                                  1),
                                                        ),
                                                        value: downloadProgress
                                                            .progress),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              child: Center(
                                                child: Icon(
                                                  JamIcons.close_circle_f,
                                                  color: Theme.of(context)
                                                      .accentColor,
                                                ),
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
                  child: Icon(JamIcons.chevron_left),
                  onTap: () {
                    widget.controller.animateToPage(
                        widget.controller.page.toInt() - 1,
                        duration: Duration(milliseconds: 200),
                        curve: Curves.fastOutSlowIn);
                    HapticFeedback.vibrate();
                  },
                ),
              ),
        main.prefs.get("premium")
            ? pageNumber ==
                    Provider.of<SetupProvider>(context, listen: false)
                            .setups
                            .length -
                        1
                ? Container()
                : Align(
                    alignment: Alignment.centerRight,
                    child: ArrowBounceAnimation(
                      child: Icon(JamIcons.chevron_right),
                      onTap: () {
                        widget.controller.animateToPage(
                            widget.controller.page.toInt() + 1,
                            duration: Duration(milliseconds: 200),
                            curve: Curves.fastOutSlowIn);
                        HapticFeedback.vibrate();
                      },
                    ),
                  )
            : pageNumber == 5
                ? Container()
                : Align(
                    alignment: Alignment.centerRight,
                    child: ArrowBounceAnimation(
                      child: Icon(JamIcons.chevron_right),
                      onTap: () {
                        widget.controller.animateToPage(
                            widget.controller.page.toInt() + 1,
                            duration: Duration(milliseconds: 200),
                            curve: Curves.fastOutSlowIn);
                        HapticFeedback.vibrate();
                      },
                    ),
                  ),
      ],
    );
  }
}
