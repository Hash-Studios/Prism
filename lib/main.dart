import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/prism/provider/prismProvider.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/home/splashScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/routes/router.dart' as router;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/services.dart';

SharedPreferences prefs;
var darkMode;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  InAppPurchaseConnection.enablePendingPurchases();
  SharedPreferences.getInstance().then((prefs) {
    darkMode = prefs.getBool('darkMode') ?? true;
    if (darkMode)
      prefs.setBool('darkMode', true);
    else
      prefs.setBool('darkMode', false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
        .then((value) => runApp(
              RestartWidget(
                child: MultiProvider(
                  providers: [
                    ChangeNotifierProvider<WallHavenProvider>(
                      create: (context) => WallHavenProvider(),
                    ),
                    ChangeNotifierProvider<PexelsProvider>(
                      create: (context) => PexelsProvider(),
                    ),
                    ChangeNotifierProvider<CategoryProvider>(
                      create: (context) => CategoryProvider(),
                    ),
                    ChangeNotifierProvider<FavouriteProvider>(
                      create: (context) => FavouriteProvider(),
                    ),
                    ChangeNotifierProvider<PrismProvider>(
                      create: (context) => PrismProvider(),
                    ),
                    ChangeNotifierProvider<ThemeModel>(
                      create: (context) => ThemeModel(
                          darkMode ? kDarkTheme : kLightTheme,
                          darkMode ? ThemeType.Dark : ThemeType.Light),
                    )
                  ],
                  child: MyApp(),
                ),
              ),
            ));
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  void getLoginStatus() async {
    prefs = await SharedPreferences.getInstance();
    globals.gAuth.googleSignIn.isSignedIn().then((value) {
      prefs.setBool("isLoggedin", value);
    });
  }

  @override
  void initState() {
    getLoginStatus();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
// initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_notification');
    var initializationSettingsIOS = IOSInitializationSettings();
    var initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: selectNotification);
    weeklyLocalNotification1();
    weeklyLocalNotification2();
    weeklyLocalNotification3();
    super.initState();
  }

  Future selectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }
  }

  Future weeklyLocalNotification1() async {
    var time = Time(17, 00, 0);
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'show weekly channel id',
        'show weekly channel name',
        'show weekly description',
        importance: Importance.Max,
        priority: Priority.High);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
      0,
      'Now there\'s more to love!',
      'New Wallpapers added daily just for you. Check them out now.',
      Day.Monday,
      time,
      platformChannelSpecifics,
      payload: 'Default_Sound',
    );
  }

  Future weeklyLocalNotification2() async {
    var time = Time(12, 00, 0);
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'show weekly channel id',
        'show weekly channel name',
        'show weekly description',
        importance: Importance.Max,
        priority: Priority.High);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
      1,
      'What are you waiting for?',
      'Indulge yourself into the new wallpaper collections now.',
      Day.Wednesday,
      time,
      platformChannelSpecifics,
      payload: 'Default_Sound',
    );
  }

  Future weeklyLocalNotification3() async {
    var time = Time(15, 00, 0);
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'show weekly channel id',
        'show weekly channel name',
        'show weekly description',
        importance: Importance.Max,
        priority: Priority.High);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
      2,
      'Want to look cool?',
      'First change your wallpaper, from our exclusive collections now.',
      Day.Friday,
      time,
      platformChannelSpecifics,
      payload: 'Default_Sound',
    );
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
    SharedPreferences.getInstance().then((prefs) {
      darkMode = prefs.getBool('darkMode') ?? true;
      if (darkMode)
        prefs.setBool('darkMode', true);
      else
        prefs.setBool('darkMode', false);
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
