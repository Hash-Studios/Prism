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

class HomeSetupScreen extends StatefulWidget {
  const HomeSetupScreen({
    Key key,
  }) : super(key: key);

  @override
  _HomeSetupScreenState createState() => _HomeSetupScreenState();
}

class _HomeSetupScreenState extends State<HomeSetupScreen> {
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
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: HomeSetupPage(future: future, controller: controller),
    );
  }
}

class HomeSetupPage extends StatefulWidget {
  const HomeSetupPage({
    Key key,
    @required this.future,
    @required this.controller,
  }) : super(key: key);

  final Future future;
  final PageController controller;

  @override
  _HomeSetupPageState createState() => _HomeSetupPageState();
}

class _HomeSetupPageState extends State<HomeSetupPage> {
  int pageNumber = 0;
  void showPremiumPopUp(Function func) {
    if (main.prefs.get("premium") == false) {
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
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: MediaQuery.of(context).size.width - 25,
                padding: const EdgeInsets.only(left: 25, top: 25),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      main.prefs.get("premium") as bool == true
                          ? Provider.of<SetupProvider>(context, listen: false)
                                  .setups
                                  .isEmpty
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
                                      .isEmpty
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
              EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.06),
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
                        itemCount: main.prefs.get("premium") == true
                            ? Provider.of<SetupProvider>(context, listen: false)
                                    .setups
                                    .isEmpty
                                ? 1
                                : Provider.of<SetupProvider>(context,
                                        listen: false)
                                    .setups
                                    .length
                            : 6,
                        itemBuilder: (context, index) => main.prefs
                                    .get("premium") as bool ==
                                true
                            ? Provider.of<SetupProvider>(context, listen: false)
                                    .setups
                                    .isEmpty
                                ? Loader()
                                : AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
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
                                            .setups[index]['image']
                                            .toString(),
                                        imageBuilder:
                                            (context, imageProvider) => Hero(
                                          tag: "CustomHerotag$index",
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.642,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.62,
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
                                                                const Offset(
                                                                    0, 19),
                                                          ),
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    .10),
                                                            blurRadius: 12,
                                                            offset:
                                                                const Offset(
                                                                    0, 15),
                                                          )
                                                        ]
                                                      : [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    .7),
                                                            blurRadius: 38,
                                                            offset:
                                                                const Offset(
                                                                    0, 19),
                                                          ),
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    .6),
                                                            blurRadius: 12,
                                                            offset:
                                                                const Offset(
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
                                        progressIndicatorBuilder:
                                            (context, url, downloadProgress) =>
                                                Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.642,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.62,
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
                                            Center(
                                          child: Icon(
                                            JamIcons.close_circle_f,
                                            color:
                                                Theme.of(context).accentColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                            : (index == 5)
                                ? AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
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
                                              0.642,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.62,
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
                                                          offset: const Offset(
                                                              0, 19),
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(.10),
                                                          blurRadius: 12,
                                                          offset: const Offset(
                                                              0, 15),
                                                        )
                                                      ]
                                                    : [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(.7),
                                                          blurRadius: 38,
                                                          offset: const Offset(
                                                              0, 19),
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(.6),
                                                          blurRadius: 12,
                                                          offset: const Offset(
                                                              0, 15),
                                                        )
                                                      ]
                                                : [],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            image: const DecorationImage(
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
                                        .isEmpty
                                    ? Loader()
                                    : AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
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
                                                    .setups[index]['image']
                                                    .toString(),
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    Hero(
                                              tag: "CustomHerotag$index",
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.642,
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.62,
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
                                                                offset:
                                                                    const Offset(
                                                                        0, 19),
                                                              ),
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .10),
                                                                blurRadius: 12,
                                                                offset:
                                                                    const Offset(
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
                                                                offset:
                                                                    const Offset(
                                                                        0, 19),
                                                              ),
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        .6),
                                                                blurRadius: 12,
                                                                offset:
                                                                    const Offset(
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
                                                  0.642,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.62,
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
                                                (context, url, error) => Center(
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
                  child: const Icon(JamIcons.chevron_left),
                ),
              ),
        main.prefs.get("premium") as bool == true
            ? pageNumber ==
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
                      child: const Icon(JamIcons.chevron_right),
                    ),
                  )
            : pageNumber == 5
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
                      child: const Icon(JamIcons.chevron_right),
                    ),
                  ),
      ],
    );
  }
}
