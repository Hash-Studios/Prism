import 'dart:async';
import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:Prism/data/profile/wallpaper/profileSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/theme/darkThemeModel.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/home/core/splashScreen.dart';
import 'package:Prism/ui/pages/onboarding/onboardingScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
// import 'package:collection/collection.dart' show IterableExtension;
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/routes/router.dart' as router;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

late Box prefs;
Directory? dir;
String? currentThemeID;
String? currentDarkThemeID;
String? currentMode;
Color? lightAccent;
Color? darkAccent;
bool? hqThumbs;
late bool optimisedWallpapers;
int? categories;
int? purity;
void main() {
  //! Uncomment next line before release
  // debugPrint = (String message, {int wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  };
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  flutterLocalNotificationsPlugin.initialize(initializationSettings).then((_) {
    // InAppPurchaseConnection.enablePendingPurchases();
    // GestureBinding.instance!.resamplingEnabled = true;
    getApplicationDocumentsDirectory().then(
      (dir) async {
        Hive.init(dir.path);
        await Hive.openBox('wallpapers');
        await Hive.openBox('collections');
        await Hive.openBox('setups');
        await Hive.openBox('localFav');
        Hive.registerAdapter(NotifDataAdapter());
        await Hive.openBox<List>('notifications');
        Hive.registerAdapter(PrismUsersAdapter());
        prefs = await Hive.openBox('prefs');
        debugPrint("Box Opened");
        if (prefs.get("systemOverlayColor") == null) {
          prefs.put("systemOverlayColor", 0xFFE57697);
        }
        currentThemeID = prefs
            .get('lightThemeID', defaultValue: "kLFrost White")
            ?.toString();
        prefs.put("lightThemeID", currentThemeID);
        currentDarkThemeID = prefs
            .get('darkThemeID', defaultValue: "kDMaterial Dark")
            ?.toString();
        prefs.put("darkThemeID", currentDarkThemeID);
        currentMode = prefs.get('themeMode')?.toString() ?? "Dark";
        prefs.put("themeMode", currentMode);
        lightAccent = Color(int.parse(
            prefs.get('lightAccent', defaultValue: "0xffe57697").toString()));
        prefs.put(
            "lightAccent",
            int.parse(lightAccent
                .toString()
                .replaceAll("Color(", "")
                .replaceAll(")", "")));
        darkAccent = Color(int.parse(
            prefs.get('darkAccent', defaultValue: "0xffe57697").toString()));
        prefs.put(
            "darkAccent",
            int.parse(darkAccent
                .toString()
                .replaceAll("Color(", "")
                .replaceAll(")", "")));
        optimisedWallpapers = prefs.get('optimisedWallpapers') == true;
        if (optimisedWallpapers) {
          prefs.put('optimisedWallpapers', true);
        } else {
          prefs.put('optimisedWallpapers', false);
        }
        categories = prefs.get('WHcategories') as int? ?? 100;
        if (categories == 100) {
          prefs.put('WHcategories', 100);
        } else {
          prefs.put('WHcategories', 111);
        }
        purity = prefs.get('WHpurity') as int? ?? 100;
        if (purity == 100) {
          prefs.put('WHpurity', 100);
        } else {
          prefs.put('WHpurity', 110);
        }
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          systemNavigationBarColor:
              Color(prefs.get('systemOverlayColor') as int),
        ));
        SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
            .then(
          (value) => runZoned<Future<void>>(
            () {
              runApp(
                RestartWidget(
                  child: MultiProvider(
                    providers: [
                      ChangeNotifierProvider<FavouriteProvider>(
                        create: (context) => FavouriteProvider(),
                      ),
                      ChangeNotifierProvider<FavouriteSetupProvider>(
                        create: (context) => FavouriteSetupProvider(),
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
                      ChangeNotifierProvider<ProfileSetupProvider>(
                        create: (context) => ProfileSetupProvider(),
                      ),
                      ChangeNotifierProvider<ThemeModel>(
                        create: (context) => ThemeModel(
                            themes[currentThemeID!]
                            // ?? kLightTheme
                            ,
                            lightAccent),
                      ),
                      ChangeNotifierProvider<DarkThemeModel>(
                        create: (context) => DarkThemeModel(
                            darkThemes[currentDarkThemeID!]
                            // ?? kDarkTheme
                            ,
                            darkAccent),
                      ),
                      ChangeNotifierProvider<ThemeModeExtended>(
                        create: (context) =>
                            ThemeModeExtended(modes[currentMode!]),
                      ),
                    ],
                    child: MyApp(),
                  ),
                ),
              );
            } as Future<void> Function(),
          ),
        );
      },
    );
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> _createNotificationChannel(
      String id, String name, String description) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const String channelGroupId = 'notifications';
    const AndroidNotificationChannelGroup androidNotificationChannelGroup =
        AndroidNotificationChannelGroup(channelGroupId, 'Notifications',
            description: 'All Prism Notifications');
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        .createNotificationChannelGroup(androidNotificationChannelGroup);

    final androidNotificationChannel = AndroidNotificationChannel(
      id,
      name,
      description,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);
  }

  // List<DisplayMode> modes = <DisplayMode>[];
  // DisplayMode? selected;
  // Future<void> fetchModes() async {
  //   try {
  //     modes = await FlutterDisplayMode.supported;
  //     debugPrint(modes.toString());
  //   } on PlatformException catch (e) {
  //     debugPrint(e.toString());
  //   }
  //   selected = modes.firstWhereOrNull((DisplayMode m) => m.selected);
  // }

  // Future<DisplayMode> getCurrentMode() async {
  //   return FlutterDisplayMode.current;
  // }

  // Future<void> setCurrentMode() async {
  //   await fetchModes();
  //   if (modes.isNotEmpty) {
  //     var width = 0;
  //     for (final mode in modes) {
  //       if (mode.width > width) {
  //         width = mode.width;
  //       }
  //     }
  //     final List<DisplayMode> maxWidthModes = [];
  //     for (final mode in modes) {
  //       if (mode.width == width) {
  //         maxWidthModes.add(mode);
  //       }
  //     }
  //     var height = 0;
  //     for (final mode in maxWidthModes) {
  //       if (mode.height > height) {
  //         height = mode.height;
  //       }
  //     }
  //     final List<DisplayMode> maxResModes = [];
  //     for (final mode in maxWidthModes) {
  //       if (mode.height == height) {
  //         maxResModes.add(mode);
  //       }
  //     }
  //     double refreshRate = 0;
  //     for (final mode in maxResModes) {
  //       if (mode.refreshRate > refreshRate) {
  //         refreshRate = mode.refreshRate;
  //       }
  //     }
  //     final List<DisplayMode> maxDisplayModes = [];
  //     for (final mode in maxResModes) {
  //       if (mode.refreshRate == refreshRate) {
  //         maxDisplayModes.add(mode);
  //       }
  //     }
  //     if (maxDisplayModes.isNotEmpty) {
  //       await FlutterDisplayMode.setMode(maxDisplayModes[0]);
  //     }
  //   }
  //   selected = modes.firstWhereOrNull((DisplayMode m) => m.selected);
  // }

  Future<bool> getLoginStatus() async {
    await globals.gAuth.googleSignIn.isSignedIn().then((value) {
      if (value) checkPremium();
      globals.prismUser.loggedIn = value;
      prefs.put("prismUser", globals.prismUser);
      return value;
    });
    return false;
  }

  @override
  void initState() {
    // setCurrentMode();
    FlutterDisplayMode.setHighRefreshRate();
    _createNotificationChannel(
        "followers", "Followers", "Get notifications for new followers.");
    _createNotificationChannel("recommendations", "Recommendations",
        "Get notifications for recommendations from Prism.");
    _createNotificationChannel("posts", "Posts",
        "Get notifications for posts from artists you follow.");
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
      darkTheme: Provider.of<DarkThemeModel>(context).currentTheme,
      themeMode: Provider.of<ThemeModeExtended>(context).currentMode,
      // debugShowCheckedModeBanner: false,
      home: ((prefs.get('onboarded_new') as bool?) ?? false)
          ? SplashWidget()
          : OnboardingScreen(),
    );
  }
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({this.child});
  final Widget? child;
  static void restartApp(BuildContext context) {
    router.navStack = ["Home"];
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Color(prefs.get('systemOverlayColor') as int),
    ));
    observer = FirebaseAnalyticsObserver(analytics: analytics);
    context.findAncestorStateOfType<_RestartWidgetState>()!.restartApp();
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
      currentThemeID =
          prefs.get('lightThemeID', defaultValue: "kLFrost White")?.toString();
      prefs.put("lightThemeID", currentThemeID);
      currentDarkThemeID =
          prefs.get('darkThemeID', defaultValue: "kDMaterial Dark")?.toString();
      prefs.put("darkThemeID", currentDarkThemeID);
      currentMode = prefs.get('themeMode')?.toString() ?? "Dark";
      prefs.put("themeMode", currentMode);
      lightAccent = Color(int.parse(
          prefs.get('lightAccent', defaultValue: "0xffe57697").toString()));
      prefs.put(
          "lightAccent",
          int.parse(lightAccent
              .toString()
              .replaceAll("Color(", "")
              .replaceAll(")", "")));
      darkAccent = Color(int.parse(
          prefs.get('darkAccent', defaultValue: "0xffe57697").toString()));
      prefs.put(
          "darkAccent",
          int.parse(darkAccent
              .toString()
              .replaceAll("Color(", "")
              .replaceAll(")", "")));
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child!,
    );
  }
}
