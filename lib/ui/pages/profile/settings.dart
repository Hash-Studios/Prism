import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:Prism/ui/widgets/profile/studioList.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:animations/animations.dart';
import 'package:Prism/global/globals.dart' as globals;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    Key key,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool optWall = (main.prefs.get('optimisedWallpapers') ?? true) as bool;
  int categories = (main.prefs.get('WHcategories') ?? 100) as int;
  int purity = (main.prefs.get('WHpurity') ?? 100) as int;
  final TextEditingController _twitterController = TextEditingController();
  final TextEditingController _igController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (navStack.length > 1) navStack.removeLast();
        debugPrint(navStack.toString());
        return true;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: const PreferredSize(
            preferredSize: Size(double.infinity, 55),
            child: HeadingChipBar(
              current: "Settings",
            ),
          ),
          body: ListView(children: <Widget>[
            if (main.prefs.get("premium") == true)
              Container()
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: config.Colors().mainAccentColor(1) == Colors.black
                          ? Colors.grey
                          : config.Colors().mainAccentColor(1),
                    ),
                  ),
                ),
              ),
            Column(
              children: <Widget>[
                if (main.prefs.get("premium") == true)
                  Container()
                else
                  ListTile(
                    onTap: () {
                      if (main.prefs.get("isLoggedin") == false) {
                        googleSignInPopUp(context, () {
                          if (main.prefs.get("premium") == true) {
                            main.RestartWidget.restartApp(context);
                          } else {
                            Navigator.pushNamed(context, premiumRoute);
                          }
                        });
                      } else {
                        Navigator.pushNamed(context, premiumRoute);
                      }
                    },
                    leading: const Icon(JamIcons.instant_picture_f),
                    title: Text(
                      "Buy Premium",
                      style: TextStyle(
                          color: Theme.of(context).accentColor,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Proxima Nova"),
                    ),
                    subtitle: const Text(
                      "Get unlimited setups and filters.",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'General',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: config.Colors().mainAccentColor(1) == Colors.black
                        ? Colors.grey
                        : config.Colors().mainAccentColor(1),
                  ),
                ),
              ),
            ),
            ListTile(
              onTap: () {
                Navigator.pushNamed(context, themeViewRoute, arguments: [
                  Provider.of<ThemeModel>(context, listen: false).currentTheme,
                  Color(main.prefs.get("mainAccentColor") as int),
                  Provider.of<ThemeModel>(context, listen: false)
                      .returnThemeIndex(
                    Provider.of<ThemeModel>(context, listen: false)
                        .currentTheme,
                  )
                ]);
              },
              leading: const Icon(JamIcons.wrench),
              title: Text(
                "Themes",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: const Text(
                "Toggle app theme",
                style: TextStyle(fontSize: 12),
              ),
            ),
            ListTile(
                leading: const Icon(
                  JamIcons.pie_chart_alt,
                ),
                title: Text(
                  "Clear Cache",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: const Text(
                  "Clear locally cached images",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  DefaultCacheManager().emptyCache();
                  PaintingBinding.instance.imageCache.clear();
                  await Hive.box('wallpapers').deleteFromDisk();
                  await Hive.openBox('wallpapers');
                  await Hive.box('collections').deleteFromDisk();
                  await Hive.openBox('collections');
                  await Hive.box('setups').deleteFromDisk();
                  await Hive.openBox('setups');
                  toasts.codeSend("Cleared cache!");
                }),
            SwitchListTile(
                activeColor: config.Colors().mainAccentColor(1),
                secondary: const Icon(
                  JamIcons.dashboard,
                ),
                value: optWall,
                title: Text(
                  "Wallpaper Optimisation",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: optWall
                    ? const Text(
                        "Disabling this might lead to High Internet Usage",
                        style: TextStyle(fontSize: 12),
                      )
                    : const Text(
                        "Enable this to optimise Wallpapers according to your device",
                        style: TextStyle(fontSize: 12),
                      ),
                onChanged: (bool value) async {
                  setState(() {
                    optWall = value;
                  });
                  main.prefs.put('optimisedWallpapers', value);
                }),
            SwitchListTile(
                activeColor: config.Colors().mainAccentColor(1),
                secondary: const Icon(
                  JamIcons.picture,
                ),
                value: categories == 111,
                title: Text(
                  "Show Anime Wallpapers",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: categories == 111
                    ? const Text(
                        "Disable this to hide anime wallpapers",
                        style: TextStyle(fontSize: 12),
                      )
                    : const Text(
                        "Enable this to show anime wallpapers",
                        style: TextStyle(fontSize: 12),
                      ),
                onChanged: (bool value) async {
                  if (value == true) {
                    setState(() {
                      categories = 111;
                    });
                    main.prefs.put('WHcategories', 111);
                  } else {
                    setState(() {
                      categories = 100;
                    });
                    main.prefs.put('WHcategories', 100);
                  }
                }),
            SwitchListTile(
                activeColor: config.Colors().mainAccentColor(1),
                secondary: const Icon(
                  JamIcons.stop_sign,
                ),
                value: purity == 110,
                title: Text(
                  "Show Sketchy Wallpapers",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: purity == 110
                    ? const Text(
                        "Disable this to hide sketchy wallpapers",
                        style: TextStyle(fontSize: 12),
                      )
                    : const Text(
                        "Enable this to show sketchy wallpapers",
                        style: TextStyle(fontSize: 12),
                      ),
                onChanged: (bool value) async {
                  if (value == true) {
                    setState(() {
                      purity = 110;
                    });
                    main.prefs.put('WHpurity', 110);
                  } else {
                    setState(() {
                      purity = 100;
                    });
                    main.prefs.put('WHpurity', 100);
                  }
                }),
            ListTile(
              onTap: () {
                main.RestartWidget.restartApp(context);
              },
              leading: const Icon(JamIcons.refresh),
              title: Text(
                "Restart App",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: const Text(
                "Force the application to restart",
                style: TextStyle(fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: config.Colors().mainAccentColor(1) == Colors.black
                        ? Colors.grey
                        : config.Colors().mainAccentColor(1),
                  ),
                ),
              ),
            ),
            if (main.prefs.get("isLoggedin") == false)
              ListTile(
                onTap: () {
                  final Dialog loaderDialog = Dialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Theme.of(context).primaryColor),
                      width: MediaQuery.of(context).size.width * .7,
                      height: MediaQuery.of(context).size.height * .3,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                  if (main.prefs.get("isLoggedin") == false) {
                    showDialog(
                        barrierDismissible: false,
                        context: context,
                        builder: (BuildContext context) => loaderDialog);
                    globals.gAuth.signInWithGoogle().then((value) {
                      toasts.codeSend("Login Successful!");
                      main.prefs.put("isLoggedin", true);
                      Navigator.pop(context);
                      main.RestartWidget.restartApp(context);
                    }).catchError((e) {
                      debugPrint(e.toString());
                      Navigator.pop(context);
                      main.prefs.put("isLoggedin", false);
                      toasts.error("Something went wrong, please try again!");
                    });
                  } else {
                    main.RestartWidget.restartApp(context);
                  }
                },
                leading: const Icon(JamIcons.log_in),
                title: Text(
                  "Log in",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: const Text(
                  "Log in to sync data across devices",
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              Column(
                children: <Widget>[
                  if (main.prefs.get("isLoggedin") == true)
                    Column(
                      children: [
                        ListTile(
                            leading: const Icon(
                              JamIcons.heart,
                            ),
                            title: Text(
                              "Clear favourite walls",
                              style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Proxima Nova"),
                            ),
                            subtitle: const Text(
                              "Remove all favourite wallpapers",
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () async {
                              showModal(
                                context: context,
                                configuration:
                                    const FadeScaleTransitionConfiguration(),
                                builder: (context) => AlertDialog(
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  content: Container(
                                    height: 50,
                                    width: 250,
                                    child: Center(
                                      child: Text(
                                        "Do you want remove all your favourite wallpapers?",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline4,
                                      ),
                                    ),
                                  ),
                                  actions: <Widget>[
                                    FlatButton(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5)),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        toasts.error(
                                            "Cleared all favourite wallpapers!");
                                        Provider.of<FavouriteProvider>(context,
                                                listen: false)
                                            .deleteData();
                                      },
                                      child: Text(
                                        'YES',
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          color: config.Colors()
                                              .mainAccentColor(1),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: FlatButton(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        color:
                                            config.Colors().mainAccentColor(1),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text(
                                          'NO',
                                          style: TextStyle(
                                            fontSize: 16.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                              );
                            }),
                        ListTile(
                            leading: const Icon(
                              JamIcons.heart,
                            ),
                            title: Text(
                              "Clear favourite setups",
                              style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Proxima Nova"),
                            ),
                            subtitle: const Text(
                              "Remove all favourite setups",
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () async {
                              showModal(
                                context: context,
                                configuration:
                                    const FadeScaleTransitionConfiguration(),
                                builder: (context) => AlertDialog(
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  content: Container(
                                    height: 50,
                                    width: 250,
                                    child: Center(
                                      child: Text(
                                        "Do you want remove all your favourite setups?",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline4,
                                      ),
                                    ),
                                  ),
                                  actions: <Widget>[
                                    FlatButton(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5)),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        toasts.error(
                                            "Cleared all favourite setups!");
                                        Provider.of<FavouriteSetupProvider>(
                                                context,
                                                listen: false)
                                            .deleteData();
                                      },
                                      child: Text(
                                        'YES',
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          color: config.Colors()
                                              .mainAccentColor(1),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: FlatButton(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        color:
                                            config.Colors().mainAccentColor(1),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text(
                                          'NO',
                                          style: TextStyle(
                                            fontSize: 16.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                              );
                            }),
                        ListTile(
                            leading: const Icon(
                              JamIcons.twitter,
                            ),
                            title: Text(
                              "Connect your Twitter",
                              style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Proxima Nova"),
                            ),
                            subtitle: const Text(
                              "Show your twitter account on your profile",
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () async {
                              showModal(
                                context: context,
                                configuration:
                                    const FadeScaleTransitionConfiguration(),
                                builder: (context) => AlertDialog(
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  content: Container(
                                    height: 100,
                                    width: 250,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text(
                                            "Enter your Twitter username",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline4,
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(500),
                                                color: Theme.of(context)
                                                    .hintColor),
                                            child: TextField(
                                              cursorColor: config.Colors()
                                                  .mainAccentColor(1),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headline5
                                                  .copyWith(
                                                      color: Theme.of(context)
                                                          .accentColor),
                                              controller: _twitterController,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.only(
                                                        left: 30, top: 15),
                                                border: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                hintText:
                                                    "Ex - PrismWallpapers",
                                                hintStyle: Theme.of(context)
                                                    .textTheme
                                                    .headline5
                                                    .copyWith(
                                                        fontSize: 14,
                                                        color: Theme.of(context)
                                                            .accentColor),
                                                suffixIcon: Icon(
                                                  JamIcons.twitter,
                                                  color: Theme.of(context)
                                                      .accentColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: <Widget>[
                                    FlatButton(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5)),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        'CANCEL',
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          color: config.Colors()
                                              .mainAccentColor(1),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: FlatButton(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        color:
                                            config.Colors().mainAccentColor(1),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await setUserTwitter(
                                              "https://www.twitter.com/${_twitterController.text}",
                                              main.prefs.get("id").toString());
                                          toasts
                                              .codeSend("Successfully linked!");
                                        },
                                        child: const Text(
                                          'SAVE',
                                          style: TextStyle(
                                            fontSize: 16.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                              );
                            }),
                        ListTile(
                            leading: const Icon(
                              JamIcons.instagram,
                            ),
                            title: Text(
                              "Connect your Instagram",
                              style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Proxima Nova"),
                            ),
                            subtitle: const Text(
                              "Show your IG account on your profile",
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () async {
                              showModal(
                                context: context,
                                configuration:
                                    const FadeScaleTransitionConfiguration(),
                                builder: (context) => AlertDialog(
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  content: Container(
                                    height: 100,
                                    width: 250,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text(
                                            "Enter your Instagram username",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline4,
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(500),
                                                color: Theme.of(context)
                                                    .hintColor),
                                            child: TextField(
                                              cursorColor: config.Colors()
                                                  .mainAccentColor(1),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headline5
                                                  .copyWith(
                                                      color: Theme.of(context)
                                                          .accentColor),
                                              controller: _igController,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.only(
                                                        left: 30, top: 15),
                                                border: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                hintText:
                                                    "Ex - PrismWallpapers",
                                                hintStyle: Theme.of(context)
                                                    .textTheme
                                                    .headline5
                                                    .copyWith(
                                                        fontSize: 14,
                                                        color: Theme.of(context)
                                                            .accentColor),
                                                suffixIcon: Icon(
                                                  JamIcons.instagram,
                                                  color: Theme.of(context)
                                                      .accentColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: <Widget>[
                                    FlatButton(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5)),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        'CANCEL',
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          color: config.Colors()
                                              .mainAccentColor(1),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: FlatButton(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                        color:
                                            config.Colors().mainAccentColor(1),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await setUserIG(
                                              "https://www.instagram.com/${_igController.text}",
                                              main.prefs.get("id").toString());
                                          toasts
                                              .codeSend("Successfully linked!");
                                        },
                                        child: const Text(
                                          'SAVE',
                                          style: TextStyle(
                                            fontSize: 16.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                              );
                            }),
                        ListTile(
                            leading: const Icon(
                              JamIcons.log_out,
                            ),
                            title: Text(
                              "Logout",
                              style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Proxima Nova"),
                            ),
                            subtitle: Text(
                              main.prefs.get("email").toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              globals.gAuth.signOutGoogle();
                              toasts.codeSend("Log out Successful!");
                              main.RestartWidget.restartApp(context);
                            }),
                      ],
                    )
                  else
                    Container(),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Support',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: config.Colors().mainAccentColor(1) == Colors.black
                        ? Colors.grey
                        : config.Colors().mainAccentColor(1),
                  ),
                ),
              ),
            ),
            const StudioList(),
          ])),
    );
  }
}
