import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/auth/userOldModel.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/nav_stack.dart' as router;
import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/category_feed.dart';
import 'package:Prism/features/favourite_setups/favourite_setups.dart';
import 'package:Prism/features/favourite_walls/favourite_walls.dart';
import 'package:Prism/features/palette/palette.dart';
import 'package:Prism/features/profile_setups/profile_setups.dart';
import 'package:Prism/features/profile_walls/profile_walls.dart';
import 'package:Prism/features/public_profile/public_profile.dart';
import 'package:Prism/features/setups/setups.dart';
import 'package:Prism/features/theme_dark/theme_dark.dart';
import 'package:Prism/features/theme_light/theme_light.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/features/user_search/user_search.dart';
import 'package:Prism/firebase_options.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/localNotification.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

String userHiveKey = "prismUserV2-1";
late Box prefs;
String? currentThemeID;
String? currentDarkThemeID;
String? currentMode;
Color? lightAccent;
Color? darkAccent;
late bool optimisedWallpapers;
int? categories;
int? purity;
late LocalNotification localNotification;

int _to8BitChannel(double value) {
  final channel = (value * 255).round();
  if (channel < 0) return 0;
  if (channel > 255) return 255;
  return channel;
}

int _colorValueFromPrefs(dynamic rawValue, {required int fallback}) {
  if (rawValue == null) return fallback;

  if (rawValue is int) return rawValue;
  if (rawValue is Color) return rawValue.toARGB32();

  final raw = rawValue.toString().trim();

  final hexMatch = RegExp('0x[0-9a-fA-F]+').firstMatch(raw);
  if (hexMatch != null) {
    return int.tryParse(hexMatch.group(0)!) ?? fallback;
  }

  if (RegExp('^-?\\d+\$').hasMatch(raw)) {
    return int.tryParse(raw) ?? fallback;
  }

  final alpha = RegExp(r'alpha:\s*([0-9]*\.?[0-9]+)').firstMatch(raw);
  final red = RegExp(r'red:\s*([0-9]*\.?[0-9]+)').firstMatch(raw);
  final green = RegExp(r'green:\s*([0-9]*\.?[0-9]+)').firstMatch(raw);
  final blue = RegExp(r'blue:\s*([0-9]*\.?[0-9]+)').firstMatch(raw);

  if (alpha != null && red != null && green != null && blue != null) {
    final a = _to8BitChannel(double.tryParse(alpha.group(1)!) ?? 1.0);
    final r = _to8BitChannel(double.tryParse(red.group(1)!) ?? 0.0);
    final g = _to8BitChannel(double.tryParse(green.group(1)!) ?? 0.0);
    final b = _to8BitChannel(double.tryParse(blue.group(1)!) ?? 0.0);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  return fallback;
}

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final SentryConfig sentryConfig = _resolveSentryConfig();
      await _initializeMonitoring(sentryConfig);

      PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
        logger.e(
          'Uncaught platform error',
          tag: 'PlatformError',
          error: error,
          stackTrace: stackTrace,
        );
        return true;
      };

      await MobileAds.instance.initialize();
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details, forceReport: true);
        logger.e(
          'Uncaught Flutter framework error',
          tag: 'FlutterError',
          error: details.exception,
          stackTrace: details.stack,
          fields: <String, Object?>{
            if (details.library != null) 'library': details.library,
            if (details.context != null) 'context': details.context.toString(),
          },
        );
      };

      localNotification = LocalNotification();

      const skipFirebaseInit = bool.fromEnvironment('SKIP_FIREBASE_INIT');
      if (!skipFirebaseInit) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          FirebaseInAppMessaging.instance.setMessagesSuppressed(false);
        } catch (error, stackTrace) {
          logger.w(
            'Firebase initialization failed; continuing without Firebase-backed startup features.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      } else {
        logger.w('Skipping Firebase initialization for this run (SKIP_FIREBASE_INIT=true).');
      }

      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
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
      final systemOverlayColorValue = _colorValueFromPrefs(
        prefs.get("systemOverlayColor"),
        fallback: 0xFFE57697,
      );
      prefs.put("systemOverlayColor", systemOverlayColorValue);
      currentThemeID = prefs.get('lightThemeID', defaultValue: "kLFrost White")?.toString();
      prefs.put("lightThemeID", currentThemeID);
      currentDarkThemeID = prefs.get('darkThemeID', defaultValue: "kDMaterial Dark")?.toString();
      prefs.put("darkThemeID", currentDarkThemeID);
      currentMode = prefs.get('themeMode')?.toString() ?? "Dark";
      prefs.put("themeMode", currentMode);
      final lightAccentValue = _colorValueFromPrefs(
        prefs.get('lightAccent'),
        fallback: 0xFFE57697,
      );
      lightAccent = Color(lightAccentValue);
      prefs.put("lightAccent", lightAccentValue);

      final darkAccentValue = _colorValueFromPrefs(
        prefs.get('darkAccent'),
        fallback: 0xFFE57697,
      );
      darkAccent = Color(darkAccentValue);
      prefs.put("darkAccent", darkAccentValue);
      optimisedWallpapers = prefs.get('optimisedWallpapers') == true;
      prefs.put('optimisedWallpapers', false);
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
        systemNavigationBarColor: Color(systemOverlayColorValue),
      ));
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

      runApp(
        RestartWidget(
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
              BlocProvider<CategoryFeedBloc>(
                create: (_) => getIt<CategoryFeedBloc>()..add(const CategoryFeedEvent.started()),
              ),
              BlocProvider<ProfileWallsBloc>(
                create: (_) => getIt<ProfileWallsBloc>(),
              ),
              BlocProvider<FavouriteWallsBloc>(
                create: (_) => getIt<FavouriteWallsBloc>(),
              ),
              BlocProvider<FavouriteSetupsBloc>(
                create: (_) => getIt<FavouriteSetupsBloc>(),
              ),
              BlocProvider<ProfileSetupsBloc>(
                create: (_) => getIt<ProfileSetupsBloc>(),
              ),
              BlocProvider<SetupsBloc>(
                create: (_) => getIt<SetupsBloc>(),
              ),
              BlocProvider<PublicProfileBloc>(
                create: (_) => getIt<PublicProfileBloc>(),
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
      );
    },
    (obj, stacktrace) {
      logger.e(
        'Uncaught zone error',
        tag: 'ZoneError',
        error: obj,
        stackTrace: stacktrace,
      );
    },
  );
}

SentryConfig _resolveSentryConfig() {
  const String fallbackEnvironment = kReleaseMode ? 'production' : 'staging';
  final String fallbackRelease = 'Prism@${globals.currentAppVersion}+${globals.currentAppVersionCode}';
  return SentryConfig.fromEnvironment(
    fallbackEnvironment: fallbackEnvironment,
    fallbackRelease: fallbackRelease,
    fallbackDist: globals.currentAppVersionCode,
  );
}

Future<void> _initializeMonitoring(SentryConfig config) async {
  if (!config.enabled) {
    MonitoringRuntime.reset();
    return;
  }

  try {
    await SentryFlutter.init((options) {
      options.dsn = config.dsn;
      options.environment = config.environment;
      if (config.release.isNotEmpty) {
        options.release = config.release;
      }
      if (config.dist.isNotEmpty) {
        options.dist = config.dist;
      }
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0.1;
      options.attachStacktrace = true;
      options.enableAutoNativeBreadcrumbs = true;
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    });
    MonitoringRuntime.reporter = const SentryErrorReporter();
    await MonitoringRuntime.reporter.addBreadcrumb(
      message: 'Sentry initialized',
      category: 'app.startup',
      data: <String, Object?>{
        'environment': config.environment,
        if (config.release.isNotEmpty) 'release': config.release,
        if (config.dist.isNotEmpty) 'dist': config.dist,
      },
    );
  } catch (error, stackTrace) {
    MonitoringRuntime.reset();
    logger.w(
      'Sentry initialization failed; continuing without remote error reporting.',
      tag: 'Sentry',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppRouter _appRouter;

  Future<bool> getLoginStatus() async {
    final bool value = await globals.gAuth.isSignedIn();
    if (value) {
      if (prefs.get("logouteveryoneaugust2021", defaultValue: false) == false) {
        globals.gAuth.signOutGoogle();
        prefs.put("logouteveryoneaugust2021", true);
        toasts.codeSend("Please login again, to enjoy the app!");
      }
    } else if (!value) {
      prefs.put("logouteveryoneaugust2021", true);
    }
    if (value) {
      checkPremium();
    }
    globals.prismUser.loggedIn = value;
    prefs.put(userHiveKey, globals.prismUser);
    await syncSentryUserScope(
      loggedIn: globals.prismUser.loggedIn,
      id: globals.prismUser.id,
      email: globals.prismUser.email,
      username: globals.prismUser.username,
    );
    return value;
  }

  Future<void> _configureDisplayMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } on MissingPluginException catch (e, st) {
      logger.w(
        'Display mode plugin unavailable on this platform/build.',
        error: e,
        stackTrace: st,
      );
    } catch (e, st) {
      logger.w(
        'Failed to set high refresh rate.',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _configureLocalNotificationChannels() async {
    try {
      await localNotification.createNotificationChannel(
        "followers",
        "Followers",
        "Get notifications for new followers.",
        true,
      );
      await localNotification.createNotificationChannel(
        "recommendations",
        "Recommendations",
        "Get notifications for recommendations from Prism.",
        true,
      );
      await localNotification.createNotificationChannel(
        "posts",
        "Posts",
        "Get notifications for posts from artists you follow.",
        true,
      );
      await localNotification.createNotificationChannel(
        "downloads",
        "Downloads",
        "Get notifications for download progress of wallpapers.",
        false,
      );
    } catch (e, st) {
      logger.w(
        'Failed to configure local notification channels.',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(
      initialRouteName: ((prefs.get('onboarded_new') as bool?) ?? false) ? splashRoute : onboardingRoute,
    );
    unawaited(_configureDisplayMode());
    unawaited(_configureLocalNotificationChannels());
    unawaited(getLoginStatus());
    unawaited(localNotification.fetchNotificationData(context));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _appRouter.config(),
      theme: context.prismLightTheme(),
      darkTheme: context.prismDarkTheme(),
      themeMode: context.prismThemeMode(),
    );
  }
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({this.child});
  final Widget? child;
  // ignore: unreachable_from_main
  static void restartApp(BuildContext context) {
    router.resetNavStack();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Color(
        _colorValueFromPrefs(
          prefs.get('systemOverlayColor'),
          fallback: 0xFFE57697,
        ),
      ),
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
      final lightAccentValue = _colorValueFromPrefs(
        prefs.get('lightAccent'),
        fallback: 0xFFE57697,
      );
      lightAccent = Color(lightAccentValue);
      prefs.put("lightAccent", lightAccentValue);

      final darkAccentValue = _colorValueFromPrefs(
        prefs.get('darkAccent'),
        fallback: 0xFFE57697,
      );
      darkAccent = Color(darkAccentValue);
      prefs.put("darkAccent", darkAccentValue);
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
