import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/home/bottomNavBar.dart';
// import 'package:Prism/ui/widgets/popup/proPopUp.dart';
import 'package:Prism/ui/widgets/setups/arrowAnimation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;

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
    print(navStack);
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
      Navigator.pushNamed(context, PremiumRoute);
      // premiumPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        Padding(
          padding:
              EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
          child: FutureBuilder(
              future: widget.future,
              builder: (context, snapshot) {
                if (snapshot == null) {
                  print("snapshot null");
                  return Center(child: Loader());
                }
                if (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none) {
                  print("snapshot none, waiting");
                  return Center(child: Loader());
                } else {
                  Future.delayed(Duration(seconds: 0))
                      .then((value) => setState(() {
                            pageNumber;
                          }));
                  return SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
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
                      itemBuilder: (context, index) => main.prefs.get("premium")
                          ? Provider.of<SetupProvider>(context, listen: false)
                                      .setups
                                      .length ==
                                  0
                              ? Loader()
                              : Padding(
                                  padding: EdgeInsets.only(
                                      top: MediaQuery.of(context).size.height *
                                          0.0299),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: CachedNetworkImage(
                                      imageUrl: Provider.of<SetupProvider>(
                                              context,
                                              listen: false)
                                          .setups[index]['image'],
                                      imageBuilder: (context, imageProvider) =>
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
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            image: DecorationImage(
                                                image: imageProvider,
                                                fit: BoxFit.fill),
                                          ),
                                        ),
                                      ),
                                      placeholder: (context, url) => Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.712,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.72,
                                        child: Center(
                                          child: Loader(),
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
                              ? Padding(
                                  padding: EdgeInsets.only(
                                      top: MediaQuery.of(context).size.height *
                                          0.0299),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Hero(
                                      tag: "CustomHerotag$index",
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.712,
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.72,
                                        decoration: BoxDecoration(
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
                                  : Padding(
                                      padding: EdgeInsets.only(
                                          top: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.0299),
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
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                image: DecorationImage(
                                                    image: imageProvider,
                                                    fit: BoxFit.fill),
                                              ),
                                            ),
                                          ),
                                          placeholder: (context, url) =>
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
                                              child: Loader(),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
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
                  );
                }
              }),
        ),
        Positioned(
          top: 0,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.1,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              color: Theme.of(context).hintColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  main.prefs.get("premium")
                      ? Provider.of<SetupProvider>(context, listen: false)
                                  .setups
                                  .length ==
                              0
                          ? ""
                          : Provider.of<SetupProvider>(context, listen: false)
                              .setups[pageNumber]['name']
                      : (pageNumber == 5)
                          ? "Buy Premium"
                          : Provider.of<SetupProvider>(context, listen: false)
                                      .setups
                                      .length ==
                                  0
                              ? ""
                              : Provider.of<SetupProvider>(context,
                                      listen: false)
                                  .setups[pageNumber]['name'],
                  style: Theme.of(context)
                      .textTheme
                      .headline1
                      .copyWith(fontSize: 30),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.75,
                  child: Text(
                    main.prefs.get("premium")
                        ? Provider.of<SetupProvider>(context, listen: false)
                                    .setups
                                    .length ==
                                0
                            ? ""
                            : Provider.of<SetupProvider>(context, listen: false)
                                .setups[pageNumber]['desc']
                        : (pageNumber == 5)
                            ? "to view more setups."
                            : Provider.of<SetupProvider>(context, listen: false)
                                        .setups
                                        .length ==
                                    0
                                ? ""
                                : Provider.of<SetupProvider>(context,
                                        listen: false)
                                    .setups[pageNumber]['desc'],
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headline4
                        .copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
          child: GestureDetector(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.87,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: Theme.of(context).accentColor == Color(0xFF2F2F2F)
                        ? AssetImage('assets/images/Black.png')
                        : AssetImage('assets/images/White.png'),
                    fit: BoxFit.fill),
              ),
            ),
            onPanUpdate: (details) {
              if (details.delta.dx < -10) {
                widget.controller.animateToPage(
                    widget.controller.page.toInt() + 1,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn);
                HapticFeedback.vibrate();
              } else if (details.delta.dx > 10) {
                widget.controller.animateToPage(
                    widget.controller.page.toInt() - 1,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn);
                HapticFeedback.vibrate();
              }
            },
            onTap: () {
              if (pageNumber == 5) {
                showPremiumPopUp(() {
                  main.RestartWidget.restartApp(context);
                });
              } else {
                Navigator.pushNamed(context, SetupViewRoute,
                    arguments: [pageNumber]);
              }
            },
          ),
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
                        duration: Duration(milliseconds: 300),
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
                            duration: Duration(milliseconds: 300),
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
                            duration: Duration(milliseconds: 300),
                            curve: Curves.fastOutSlowIn);
                        HapticFeedback.vibrate();
                      },
                    ),
                  ),
      ],
    );
  }
}
