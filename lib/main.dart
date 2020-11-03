import 'dart:async';
import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/home/core/splashScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/routes/router.dart' as router;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/config.dart' as config;

Box prefs;
Directory dir;
String currentThemeID;
bool hqThumbs;
bool optimisedWallpapers;
void main() {
  //! Uncomment next line before release
  // debugPrint = (String message, {int wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();
  InAppPurchaseConnection.enablePendingPurchases();
  GestureBinding.instance.resamplingEnabled = true;
  getApplicationDocumentsDirectory().then((dir) async {
    Hive.init(dir.path);
    await Hive.openBox('wallpapers');
    await Hive.openBox('collections');
    await Hive.openBox('setups');
    Hive.registerAdapter(NotifDataAdapter());
    await Hive.openBox<List>('notifications');
    prefs = await Hive.openBox('prefs');
    debugPrint("Box Opened");
    if (prefs.get("mainAccentColor") == null) {
      prefs.put("mainAccentColor", 0xFFE57697);
    }
    hqThumbs = (prefs.get('hqThumbs') as bool) ?? false;
    if (hqThumbs) {
      prefs.put('hqThumbs', true);
    } else {
      prefs.put('hqThumbs', false);
    }
    currentThemeID = prefs.get('themeID')?.toString() ?? "kDMaterial Dark";
    prefs.put("themeID", currentThemeID);
    optimisedWallpapers = prefs.get('optimisedWallpapers') == true ?? true;
    if (optimisedWallpapers) {
      prefs.put('optimisedWallpapers', true);
    } else {
      prefs.put('optimisedWallpapers', false);
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: config.Colors().mainAccentColor(1),
      ));
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
          .then((value) => runZoned<Future<void>>(() {
                runApp(
                  RestartWidget(
                    child: MultiProvider(
                      providers: [
                        // ChangeNotifierProvider<TabProvider>(
                        //   create: (context) => TabProvider(),
                        // ),
                        ChangeNotifierProvider<FavouriteProvider>(
                          create: (context) => FavouriteProvider(),
                        ),
                        ChangeNotifierProvider<CategorySupplier>(
                          create: (context) => CategorySupplier(),
                        ),
                        ChangeNotifierProvider<SetupProvider>(
                          create: (context) => SetupProvider(),
                        ),
                        ChangeNotifierProvider<ProfileWallProvider>(
                          create: (context) => ProfileWallProvider(),
                        ),
                        ChangeNotifierProvider<ThemeModel>(
                          create: (context) =>
                              ThemeModel(themes[currentThemeID]),
                        ),
                      ],
                      child: MyApp(),
                    ),
                  ),
                );
              }));
    }
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<DisplayMode> modes = <DisplayMode>[];
  DisplayMode selected;
  Future<void> fetchModes() async {
    try {
      modes = await FlutterDisplayMode.supported;
      // modes.forEach(print);
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    }
    selected =
        modes.firstWhere((DisplayMode m) => m.selected, orElse: () => null);
  }

  Future<DisplayMode> getCurrentMode() async {
    return FlutterDisplayMode.current;
  }

  Future<void> setCurrentMode(int index) async {
    await fetchModes();
    if (modes.length > index) {
      await FlutterDisplayMode.setMode(modes[index]);
    }
    selected =
        modes.firstWhere((DisplayMode m) => m.selected, orElse: () => null);
  }

  Future<bool> getLoginStatus() async {
    prefs = await Hive.openBox('prefs');
    globals.gAuth.googleSignIn.isSignedIn().then((value) {
      if (value) checkPremium();
      prefs.put("isLoggedin", value);
      return value;
    });
  }

  @override
  void initState() {
    setCurrentMode(1);
    getLoginStatus();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: <NavigatorObserver>[observer],
      onGenerateRoute: router.generateRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (context) => UndefinedScreen(
                name: settings.name,
              )),
      theme: Provider.of<ThemeModel>(context).currentTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashWidget(),
    );
  }
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    router.navStack = ["Home"];
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Color(prefs.get("mainAccentColor") as int),
    ));
    observer = FirebaseAnalyticsObserver(analytics: analytics);
    context.findAncestorStateOfType<_RestartWidgetState>().restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
    Hive.openBox('prefs').then((prefs) {
      currentThemeID = prefs.get('themeID')?.toString() ?? "kDMaterial Dark";
      prefs.put("themeID", currentThemeID);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}
