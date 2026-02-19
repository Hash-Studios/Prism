import 'dart:async';
import 'dart:convert';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/auth/userOldModel.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:Prism/core/analytics/providers/composite_analytics_provider.dart';
import 'package:Prism/core/analytics/providers/firebase_analytics_provider.dart';
import 'package:Prism/core/analytics/providers/noop_analytics_provider.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart' as launcher_compat;
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/category_feed.dart';
import 'package:Prism/features/deep_link/deep_link.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
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
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_io/hive_io.dart';
import 'package:http/http.dart' as http;
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
const String _shortLinkResolveApiBase = 'https://prismwalls.com/api/links';

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
        logger.e('Uncaught platform error', tag: 'PlatformError', error: error, stackTrace: stackTrace);
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
      bool firebaseInitialized = false;
      if (!skipFirebaseInit) {
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
          firebaseInitialized = true;
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

      _configureAnalyticsRuntime(firebaseInitialized: firebaseInitialized);

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
      final systemOverlayColorValue = _colorValueFromPrefs(prefs.get("systemOverlayColor"), fallback: 0xFFE57697);
      prefs.put("systemOverlayColor", systemOverlayColorValue);
      currentThemeID = prefs.get('lightThemeID', defaultValue: "kLFrost White")?.toString();
      prefs.put("lightThemeID", currentThemeID);
      currentDarkThemeID = prefs.get('darkThemeID', defaultValue: "kDMaterial Dark")?.toString();
      prefs.put("darkThemeID", currentDarkThemeID);
      currentMode = prefs.get('themeMode')?.toString() ?? "Dark";
      prefs.put("themeMode", currentMode);
      final lightAccentValue = _colorValueFromPrefs(prefs.get('lightAccent'), fallback: 0xFFE57697);
      lightAccent = Color(lightAccentValue);
      prefs.put("lightAccent", lightAccentValue);

      final darkAccentValue = _colorValueFromPrefs(prefs.get('darkAccent'), fallback: 0xFFE57697);
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
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(systemNavigationBarColor: Color(systemOverlayColorValue)),
      );
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

      runApp(
        RestartWidget(
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AdsBloc>(create: (_) => getIt<AdsBloc>()),
              BlocProvider<PaletteBloc>(create: (_) => getIt<PaletteBloc>()),
              BlocProvider<UserSearchBloc>(create: (_) => getIt<UserSearchBloc>()),
              BlocProvider<CategoryFeedBloc>(
                create: (_) => getIt<CategoryFeedBloc>()..add(const CategoryFeedEvent.started()),
              ),
              BlocProvider<ProfileWallsBloc>(create: (_) => getIt<ProfileWallsBloc>()),
              BlocProvider<FavouriteWallsBloc>(create: (_) => getIt<FavouriteWallsBloc>()),
              BlocProvider<FavouriteSetupsBloc>(create: (_) => getIt<FavouriteSetupsBloc>()),
              BlocProvider<ProfileSetupsBloc>(create: (_) => getIt<ProfileSetupsBloc>()),
              BlocProvider<SetupsBloc>(create: (_) => getIt<SetupsBloc>()),
              BlocProvider<PublicProfileBloc>(create: (_) => getIt<PublicProfileBloc>()),
              BlocProvider<ThemeLightBloc>(
                create: (_) => getIt<ThemeLightBloc>()..add(const ThemeLightEvent.started()),
              ),
              BlocProvider<ThemeDarkBloc>(create: (_) => getIt<ThemeDarkBloc>()..add(const ThemeDarkEvent.started())),
              BlocProvider<ThemeModeBloc>(create: (_) => getIt<ThemeModeBloc>()..add(const ThemeModeEvent.started())),
              BlocProvider<DeepLinkBloc>(create: (_) => getIt<DeepLinkBloc>()..add(const DeepLinkEvent.started())),
            ],
            child: MyApp(),
          ),
        ),
      );
    },
    (obj, stacktrace) {
      logger.e('Uncaught zone error', tag: 'ZoneError', error: obj, stackTrace: stacktrace);
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

void _configureAnalyticsRuntime({required bool firebaseInitialized}) {
  final AnalyticsProvider provider;
  if (firebaseInitialized) {
    provider = CompositeAnalyticsProvider(<AnalyticsProvider>[FirebaseAnalyticsProvider()]);
  } else {
    provider = CompositeAnalyticsProvider(<AnalyticsProvider>[const NoopAnalyticsProvider()]);
  }

  AnalyticsRuntime.instance = ProviderBackedAppAnalytics(provider: provider);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppRouter _appRouter;
  bool _coinSyncInFlight = false;

  Future<bool> getLoginStatus() async {
    bool value = await globals.gAuth.isSignedIn();
    if (value) {
      if (prefs.get("logouteveryoneaugust2021", defaultValue: false) == false) {
        try {
          await globals.gAuth.signOutGoogle();
        } catch (e, st) {
          logger.w(
            'Forced sign-out migration failed; continuing with signed-out state.',
            tag: 'Auth',
            error: e,
            stackTrace: st,
          );
        }
        prefs.put("logouteveryoneaugust2021", true);
        toasts.codeSend("Please login again, to enjoy the app!");
        value = false;
      }
    } else if (!value) {
      prefs.put("logouteveryoneaugust2021", true);
      // Ensure stale profile data from previous sessions cannot make the app behave as logged in.
      globals.prismUser
        ..loggedIn = false
        ..premium = false
        ..subscriptionTier = 'free'
        ..id = ''
        ..email = ''
        ..username = ''
        ..name = ''
        ..bio = ''
        ..profilePhoto = globals.defaultProfilePhotoUrl
        ..coverPhoto = ''
        ..followers = <dynamic>[]
        ..following = <dynamic>[]
        ..links = <String, dynamic>{};
    }
    if (value) {
      await PurchasesService.instance.checkAndPersistPremium();
      unawaited(_syncCoinEconomy(sourceTag: 'startup_login_status'));
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

  Future<void> _syncCoinEconomy({required String sourceTag}) async {
    if (_coinSyncInFlight) {
      return;
    }
    if (!globals.prismUser.loggedIn || globals.prismUser.id.trim().isEmpty) {
      return;
    }
    _coinSyncInFlight = true;
    try {
      await CoinsService.instance.bootstrapForCurrentUser();
      await CoinsService.instance.refreshBalance();
      await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
      await CoinsService.instance.maybeAwardProDailyBonus();
      await CoinsService.instance.processPendingReferralIfEligible();
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: 'coins.main.$sourceTag', error: error, stackTrace: stackTrace);
    } finally {
      _coinSyncInFlight = false;
    }
  }

  String _referralInviterFromAction(DeepLinkActionEntity action) {
    if (action.arguments.isEmpty) {
      return '';
    }
    return action.arguments.first?.toString().trim() ?? '';
  }

  Future<void> _configureDisplayMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } on MissingPluginException catch (e, st) {
      logger.w('Display mode plugin unavailable on this platform/build.', error: e, stackTrace: st);
    } catch (e, st) {
      logger.w('Failed to set high refresh rate.', error: e, stackTrace: st);
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
      logger.w('Failed to configure local notification channels.', error: e, stackTrace: st);
    }
  }

  void _navigateForDeepLink(DeepLinkActionEntity action) {
    if (action.type == DeepLinkActionType.share) {
      _appRouter.push(ShareWallpaperViewRoute(arguments: action.arguments));
    } else if (action.type == DeepLinkActionType.user) {
      _appRouter.push(ProfileRoute(arguments: action.arguments));
    } else if (action.type == DeepLinkActionType.setup) {
      _appRouter.push(ShareSetupViewRoute(arguments: action.arguments));
    } else if (action.type == DeepLinkActionType.refer) {
      final String inviterUserId = _referralInviterFromAction(action);
      if (inviterUserId.isEmpty) {
        return;
      }
      unawaited(CoinsService.instance.setPendingReferralInviterId(inviterUserId));
      if (globals.prismUser.loggedIn) {
        unawaited(CoinsService.instance.processPendingReferralIfEligible(inviterUserId: inviterUserId));
      } else {
        toasts.codeSend('Referral saved. Sign in to claim +100 coins.');
      }
    }
  }

  DeepLinkActionEntity? _parseCanonicalUriToAction(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return null;
    }

    final segment = uri.pathSegments.first;
    if (segment == 'share') {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.share,
        route: '/share',
        arguments: <dynamic>[
          uri.queryParameters['id'],
          uri.queryParameters['provider'],
          uri.queryParameters['url'],
          uri.queryParameters['thumb'],
        ],
        rawUri: uri.toString(),
      );
    }
    if (segment == 'user') {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.user,
        route: '/follower-profile',
        arguments: <dynamic>[uri.queryParameters['username'] ?? uri.queryParameters['email']],
        rawUri: uri.toString(),
      );
    }
    if (segment == 'setup') {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.setup,
        route: '/share-setup',
        arguments: <dynamic>[uri.queryParameters['name'], uri.queryParameters['thumbUrl']],
        rawUri: uri.toString(),
      );
    }
    if (segment == 'refer') {
      final String? inviterId =
          uri.queryParameters['userID'] ??
          uri.queryParameters['userId'] ??
          uri.queryParameters['userid'] ??
          uri.queryParameters['id'];
      return DeepLinkActionEntity(
        type: DeepLinkActionType.refer,
        route: '',
        arguments: <dynamic>[inviterId],
        rawUri: uri.toString(),
      );
    }

    return null;
  }

  Future<void> _resolveAndNavigateShortCode(String code) async {
    if (code.trim().isEmpty) {
      return;
    }

    final endpoint = Uri.parse('$_shortLinkResolveApiBase/$code');
    try {
      final response = await http
          .get(endpoint, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final canonicalRaw = decoded['canonical_url'];
          if (canonicalRaw is String && canonicalRaw.isNotEmpty) {
            final canonicalUri = Uri.tryParse(canonicalRaw);
            if (canonicalUri != null) {
              final action = _parseCanonicalUriToAction(canonicalUri);
              if (action != null) {
                _navigateForDeepLink(action);
                return;
              }
            }
          }
        }
      } else {
        logger.w(
          'Short-link resolve returned non-success status.',
          fields: <String, Object?>{'status': response.statusCode, 'code': code, 'body': response.body},
        );
      }
    } catch (error, stackTrace) {
      logger.w(
        'Failed to resolve short code.',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'code': code},
      );
    }

    await launcher_compat.launchUrl(Uri.https('prismwalls.com', '/l/$code'));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appRouter = AppRouter();
    unawaited(_configureDisplayMode());
    unawaited(_configureLocalNotificationChannels());
    unawaited(getLoginStatus());
    unawaited(localNotification.fetchNotificationData(context));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncCoinEconomy(sourceTag: 'app_resumed'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeepLinkBloc, DeepLinkState>(
      listenWhen: (previous, current) => previous.latestAction?.rawUri != current.latestAction?.rawUri,
      listener: (context, state) {
        final action = state.latestAction;
        if (action == null) {
          return;
        }
        if (action.type == DeepLinkActionType.shortCode) {
          final code = action.arguments.isNotEmpty ? action.arguments.first?.toString() ?? '' : '';
          unawaited(_resolveAndNavigateShortCode(code));
          return;
        }
        _navigateForDeepLink(action);
      },
      child: MaterialApp.router(
        routerConfig: _appRouter.config(
          navigatorObservers: () => [
            ...analytics.buildNavigatorObservers(),
            if (MonitoringRuntime.reporter.isEnabled)
              SentryNavigatorObserver(enableAutoTransactions: false, ignoreRoutes: <String>['/']),
          ],
        ),
        theme: context.prismLightTheme(),
        darkTheme: context.prismDarkTheme(),
        themeMode: context.prismThemeMode(),
      ),
    );
  }
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({this.child});
  final Widget? child;
  // ignore: unreachable_from_main
  static void restartApp(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Color(_colorValueFromPrefs(prefs.get('systemOverlayColor'), fallback: 0xFFE57697)),
      ),
    );
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
      final lightAccentValue = _colorValueFromPrefs(prefs.get('lightAccent'), fallback: 0xFFE57697);
      lightAccent = Color(lightAccentValue);
      prefs.put("lightAccent", lightAccentValue);

      final darkAccentValue = _colorValueFromPrefs(prefs.get('darkAccent'), fallback: 0xFFE57697);
      darkAccent = Color(darkAccentValue);
      prefs.put("darkAccent", darkAccentValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: key, child: widget.child!);
  }
}
