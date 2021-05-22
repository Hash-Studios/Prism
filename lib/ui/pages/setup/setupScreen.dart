import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/darkThemeModel.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';
import 'package:Prism/ui/widgets/home/core/bottomNavBar.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/ui/widgets/setups/arrowAnimation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    Key? key,
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
  Future? future;

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
    Key? key,
    required this.future,
    required this.controller,
  }) : super(key: key);

  final Future? future;
  final PageController controller;

  @override
  _SetupPageState createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  int pageNumber = 0;
  void showPremiumPopUp(Function func) {
    if (globals.prismUser.loggedIn == false) {
      googleSignInPopUp(context, () {
        if (globals.prismUser.premium == false) {
          Navigator.pushNamed(context, premiumRoute);
        } else {
          func();
        }
      });
    } else {
      if (globals.prismUser.premium == false) {
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
                  Theme.of(context).errorColor,
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
                padding: EdgeInsets.only(left: 25, top: 5 + globals.notchSize!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Text(
                        Provider.of<SetupProvider>(context, listen: false)
                                .setups!
                                .isEmpty
                            ? ""
                            : Provider.of<SetupProvider>(context, listen: false)
                                .setups![pageNumber]['name']
                                .toString()
                                .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headline1!
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
                                .setups!
                                .isEmpty
                            ? 1
                            : Provider.of<SetupProvider>(context, listen: false)
                                .setups!
                                .length,
                        itemBuilder: (context, index) => Provider.of<
                                    SetupProvider>(context, listen: false)
                                .setups!
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
                                        .setups![index]['image']
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
                                            ? Provider.of<ThemeModeExtended>(
                                                            context)
                                                        .getCurrentModeStyle(
                                                            MediaQuery.of(
                                                                    context)
                                                                .platformBrightness) ==
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
                                          child: SizedBox(
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
                                            SizedBox(
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
                                              Provider.of<ThemeModeExtended>(
                                                                  context)
                                                              .getCurrentModeStyle(
                                                                  MediaQuery.of(
                                                                          context)
                                                                      .platformBrightness) ==
                                                          "Dark" &&
                                                      Provider.of<DarkThemeModel>(
                                                                  context)
                                                              .currentTheme ==
                                                          kDarkTheme2
                                                  ? Theme.of(context)
                                                              .errorColor ==
                                                          Colors.black
                                                      ? Theme.of(context)
                                                          .accentColor
                                                      : Theme.of(context)
                                                          .errorColor
                                                  : Theme.of(context)
                                                      .errorColor,
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
        if (pageNumber == 0)
          Container()
        else
          Align(
            alignment: Alignment.centerLeft,
            child: ArrowBounceAnimation(
              onTap: () {
                widget.controller.animateToPage(
                    widget.controller.page!.toInt() - 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn);
                HapticFeedback.vibrate();
              },
              child: Icon(
                JamIcons.chevron_left,
                color: Provider.of<ThemeModeExtended>(context)
                                .getCurrentModeStyle(MediaQuery.of(context)
                                    .platformBrightness) ==
                            "Dark" &&
                        Provider.of<DarkThemeModel>(context).currentTheme ==
                            kDarkTheme2
                    ? Theme.of(context).errorColor == Colors.black
                        ? Theme.of(context).accentColor
                        : Theme.of(context).errorColor
                    : Theme.of(context).errorColor,
              ),
            ),
          ),
        if (pageNumber ==
            Provider.of<SetupProvider>(context, listen: false).setups!.length -
                1)
          Container()
        else
          Align(
            alignment: Alignment.centerRight,
            child: ArrowBounceAnimation(
              onTap: () {
                widget.controller.animateToPage(
                    widget.controller.page!.toInt() + 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn);
                HapticFeedback.vibrate();
              },
              child: Icon(
                JamIcons.chevron_right,
                color: Provider.of<ThemeModeExtended>(context)
                                .getCurrentModeStyle(MediaQuery.of(context)
                                    .platformBrightness) ==
                            "Dark" &&
                        Provider.of<DarkThemeModel>(context).currentTheme ==
                            kDarkTheme2
                    ? Theme.of(context).errorColor == Colors.black
                        ? Theme.of(context).accentColor
                        : Theme.of(context).errorColor
                    : Theme.of(context).errorColor,
              ),
            ),
          ),
      ],
    );
  }
}
