import 'dart:async';
import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/auth/userOldModel.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/ui/theme/theme_bloc_utils.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart';
import 'package:Prism/data/profile/wallpaper/profileSetupProvider.dart';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/features/ads/presentation/bloc/ads_bloc.dart';
import 'package:Prism/features/palette/presentation/bloc/palette_bloc.dart';
import 'package:Prism/features/theme_dark/presentation/bloc/theme_dark_bloc.dart';
import 'package:Prism/features/theme_light/presentation/bloc/theme_light_bloc.dart';
import 'package:Prism/features/theme_mode/presentation/bloc/theme_mode_bloc.dart';
import 'package:Prism/features/user_search/presentation/bloc/user_search_bloc.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/localNotification.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/ui/pages/home/core/splashScreen.dart';
import 'package:Prism/ui/pages/onboarding/onboardingScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/routes/router.dart' as router;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

String userHiveKey = "prismUserV2-1";
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
LocalNotification localNotification = LocalNotification();
Future<void> main() async {
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message!.contains("[Home")) {
      logger.i(message);
    } else {
      logger.d(message);
    }
  };
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  FirebaseInAppMessaging.instance.setMessagesSuppressed(false);
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  };
  localNotification = LocalNotification();
  Firebase.initializeApp().then((_) {
    getApplicationDocumentsDirectory().then(
      (dir) async {
        Hive.init(dir.path);
        // await Hive.deleteBoxFromDisk('prefs');
        // Hive.ignoreTypeId<PrismUsers>(33);
        Hive.registerAdapter(PrismUsersAdapter());
        Hive.registerAdapter<InAppNotif>(InAppNotifAdapter());
        Hive.registerAdapter<PrismUsersV2>(PrismUsersV2Adapter());
        Hive.registerAdapter<PrismTransaction>(PrismTransactionAdapter());
        Hive.registerAdapter<Badge>(BadgeAdapter());
        await Hive.openBox<InAppNotif>('inAppNotifs');
        await Hive.openBox('setups');
        await Hive.openBox('localFav');
        await Hive.openBox('appsCache');
        prefs = await Hive.openBox('prefs');
        logger.d("Box Opened");
        if (prefs.get("systemOverlayColor") == null) {
          prefs.put("systemOverlayColor", 0xFFE57697);
        }
        currentThemeID = prefs.get('lightThemeID', defaultValue: "kLFrost White")?.toString();
        prefs.put("lightThemeID", currentThemeID);
        currentDarkThemeID = prefs.get('darkThemeID', defaultValue: "kDMaterial Dark")?.toString();
        prefs.put("darkThemeID", currentDarkThemeID);
        currentMode = prefs.get('themeMode')?.toString() ?? "Dark";
        prefs.put("themeMode", currentMode);
        lightAccent = Color(int.parse(prefs.get('lightAccent', defaultValue: "0xffe57697").toString()));
        prefs.put("lightAccent", int.parse(lightAccent.toString().replaceAll("Color(", "").replaceAll(")", "")));
        darkAccent = Color(int.parse(prefs.get('darkAccent', defaultValue: "0xffe57697").toString()));
        prefs.put("darkAccent", int.parse(darkAccent.toString().replaceAll("Color(", "").replaceAll(")", "")));
        optimisedWallpapers = prefs.get('optimisedWallpapers') == true;
        // if (optimisedWallpapers) {
        //   prefs.put('optimisedWallpapers', true);
        // } else {
        prefs.put('optimisedWallpapers', false);
        // }
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
        configureDependencies();
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          systemNavigationBarColor: Color(prefs.get('systemOverlayColor') as int),
        ));
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
          (value) => runZonedGuarded<Future<void>>(
            () {
              runApp(
                RestartWidget(
                  child: MultiProvider(
                    providers: [
                      ChangeNotifierProvider<UserProfileProvider>(
                        create: (context) => UserProfileProvider(),
                      ),
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
                    ],
                    child: MultiBlocProvider(
                      providers: [
                        BlocProvider<AdsBloc>(
                          create: (_) => getIt<AdsBloc>(),
                        ),
                        BlocProvider<PaletteBloc>(
                          create: (_) => getIt<PaletteBloc>(),
                        ),
                        BlocProvider<UserSearchBloc>(
                          create: (_) => getIt<UserSearchBloc>(),
                        ),
                        BlocProvider<ThemeLightBloc>(
                          create: (_) => getIt<ThemeLightBloc>()..add(const ThemeLightEvent.started()),
                        ),
                        BlocProvider<ThemeDarkBloc>(
                          create: (_) => getIt<ThemeDarkBloc>()..add(const ThemeDarkEvent.started()),
                        ),
                        BlocProvider<ThemeModeBloc>(
                          create: (_) => getIt<ThemeModeBloc>()..add(const ThemeModeEvent.started()),
                        ),
                      ],
                      child: MyApp(),
                    ),
                  ),
                ),
              );
            } as Future<void> Function(),
            (obj, stacktrace) {
              logger.e(obj, obj, stacktrace);
            },
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
  Future<bool> getLoginStatus() async {
    await globals.gAuth.googleSignIn.isSignedIn().then((value) {
      if (value) {
        if (prefs.get("logouteveryoneaugust2021", defaultValue: false) == false) {
          globals.gAuth.signOutGoogle();
          prefs.put("logouteveryoneaugust2021", true);
          toasts.codeSend("Please login again, to enjoy the app!");
        }
      } else if (!value) {
        prefs.put("logouteveryoneaugust2021", true);
      }
      if (value) checkPremium();
      globals.prismUser.loggedIn = value;
      prefs.put(userHiveKey, globals.prismUser);
      return value;
    });
    return false;
  }

  @override
  void initState() {
    FlutterDisplayMode.setHighRefreshRate();
    localNotification.createNotificationChannel("followers", "Followers", "Get notifications for new followers.", true);
    localNotification.createNotificationChannel(
        "recommendations", "Recommendations", "Get notifications for recommendations from Prism.", true);
    localNotification.createNotificationChannel(
        "posts", "Posts", "Get notifications for posts from artists you follow.", true);
    localNotification.createNotificationChannel(
        "downloads", "Downloads", "Get notifications for download progress of wallpapers.", false);
    getLoginStatus();
    localNotification.fetchNotificationData(context);
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
      theme: context.prismLightTheme(),
      darkTheme: context.prismDarkTheme(),
      themeMode: context.prismThemeMode(),
      home: ((prefs.get('onboarded_new') as bool?) ?? false) ? const SplashWidget() : OnboardingScreen(),
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
      currentThemeID = prefs.get('lightThemeID', defaultValue: "kLFrost White")?.toString();
      prefs.put("lightThemeID", currentThemeID);
      currentDarkThemeID = prefs.get('darkThemeID', defaultValue: "kDMaterial Dark")?.toString();
      prefs.put("darkThemeID", currentDarkThemeID);
      currentMode = prefs.get('themeMode')?.toString() ?? "Dark";
      prefs.put("themeMode", currentMode);
      lightAccent = Color(int.parse(prefs.get('lightAccent', defaultValue: "0xffe57697").toString()));
      prefs.put("lightAccent", int.parse(lightAccent.toString().replaceAll("Color(", "").replaceAll(")", "")));
      darkAccent = Color(int.parse(prefs.get('darkAccent', defaultValue: "0xffe57697").toString()));
      prefs.put("darkAccent", int.parse(darkAccent.toString().replaceAll("Color(", "").replaceAll(")", "")));
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
