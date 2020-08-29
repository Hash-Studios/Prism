import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/theme/thumbModel.dart';
import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:Prism/data/tabs/provider/tabsProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/home/splashScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/routes/router.dart' as router;
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/services.dart';

Box prefs;
Directory dir;
var darkMode;
var hqThumbs;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  InAppPurchaseConnection.enablePendingPurchases();
  Crashlytics.instance.enableInDevMode = false;
  FlutterError.onError = Crashlytics.instance.recordFlutterError;
  getApplicationDocumentsDirectory().then((dir) async {
    Hive.init(dir.path);
    // var box = await Hive.openBox('wallpapers');
    // box.deleteFromDisk();
    await Hive.openBox('wallpapers');
    await Hive.openBox('favourites');
    await Hive.openBox('collections');
    Hive.registerAdapter(NotifDataAdapter());
    await Hive.openBox<List>('notifications');
    prefs = await Hive.openBox('prefs');
    print("Box Opened");
    hqThumbs = prefs.get('hqThumbs') ?? false;
    if (hqThumbs)
      prefs.put('hqThumbs', true);
    else
      prefs.put('hqThumbs', false);
    darkMode = prefs.get('darkMode') ?? true;
    if (darkMode)
      prefs.put('darkMode', true);
    else
      prefs.put('darkMode', false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
        .then((value) => runZoned<Future<void>>(() {
              runApp(
                RestartWidget(
                  child: MultiProvider(
                    providers: [
                      ChangeNotifierProvider<TabProvider>(
                        create: (context) => TabProvider(),
                      ),
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
                        create: (context) => ThemeModel(
                            darkMode ? kDarkTheme : kLightTheme,
                            darkMode ? ThemeType.Dark : ThemeType.Light),
                      ),
                      ChangeNotifierProvider<ThumbModel>(
                        create: (context) => ThumbModel(
                            hqThumbs ? ThumbType.High : ThumbType.Low),
                      )
                    ],
                    child: MyApp(),
                  ),
                ),
              );
            }, onError: Crashlytics.instance.recordError));
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void getLoginStatus() async {
    prefs = await Hive.openBox('prefs');
    globals.gAuth.googleSignIn.isSignedIn().then((value) {
      if (value) checkPremium();
      prefs.put("isLoggedin", value);
    });
  }

  @override
  void initState() {
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
      home: SplashWidget(),
    );
  }
}

class RestartWidget extends StatefulWidget {
  RestartWidget({this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    router.navStack = ["Home"];
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
      darkMode = prefs.get('darkMode') ?? true;
      if (darkMode)
        prefs.put('darkMode', true);
      else
        prefs.put('darkMode', false);
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
