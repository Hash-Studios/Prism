import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_identity_sync.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:Prism/core/analytics/providers/composite_analytics_provider.dart';
import 'package:Prism/core/analytics/providers/firebase_analytics_provider.dart';
import 'package:Prism/core/analytics/providers/mixpanel_analytics_provider.dart';
import 'package:Prism/core/analytics/providers/noop_analytics_provider.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/debug/bloc_debug_observer.dart';
import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/debug/log_toast_overlay.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/flutter_error_handler.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/persistence/bootstrap/persistence_bootstrap.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/router/pending_deep_link_queue.dart';
import 'package:Prism/core/router/short_link_resolver.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/category_feed/category_feed.dart';
import 'package:Prism/features/favourite_walls/favourite_walls.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/features/startup/startup.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/firebase_options.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/local_notification.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

late LocalNotification localNotification;
const double _sentryReplaySessionSampleRate = 0.1;
const double _sentryReplayOnErrorSampleRate = 1.0;

/// Top-level FCM background message handler.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
/// Avoid any UI work here — only lightweight processing.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase.initializeApp() is already called before main() is reached, but
  // in the background isolate we may need to re-initialise.  The guard inside
  // Firebase.initializeApp makes this safe to call multiple times.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final String route = message.data['route']?.toString() ?? '';
  logger.d('Background push received: $route', tag: 'Push');
}

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
      unawaited(
        app_state.initializeRuntimeAppVersion().catchError((Object e, StackTrace s) {
          logger.w(
            'Unable to read runtime app version; falling back to static constants.',
            tag: 'AppVersion',
            error: e,
            stackTrace: s,
          );
        }),
      );
      if (kDebugMode) Bloc.observer = const BlocDebugObserver();
      localNotification = LocalNotification();

      PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
        logger.e('Uncaught platform error', tag: 'PlatformError', error: error, stackTrace: stackTrace);
        unawaited(analytics.track(const AppCrashFatalEvent()));
        return true;
      };
      installFlutterFrameworkErrorHandler();

      const skipFirebaseInit = bool.fromEnvironment('SKIP_FIREBASE_INIT');
      final SentryConfig sentryConfig = _resolveSentryConfig();

      // Start Firebase early so it can initialize while persistence and monitoring run.
      // StartupRepositoryImpl.bootstrap() also awaits this future before accessing Remote Config.
      if (!skipFirebaseInit) {
        FirebaseInit.setFuture(
          Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).then((_) => true).catchError((
            Object e,
            StackTrace s,
          ) {
            logger.w(
              'Firebase initialization failed; continuing without Firebase-backed startup features.',
              error: e,
              stackTrace: s,
            );
            return false;
          }),
        );
        // Register FCM as soon as Firebase is ready (no-op if init failed).
        unawaited(
          FirebaseInit.readyFuture.then((initialized) {
            if (initialized) {
              FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
            }
            unawaited(
              MonitoringRuntime.reporter.addBreadcrumb(
                message: 'Startup stage reached',
                category: 'app.startup.stage',
                data: <String, Object?>{'stage': 'firebase_init_completed', 'firebase_initialized': initialized},
              ),
            );
          }),
        );
      } else {
        FirebaseInit.setFuture(Future<bool>.value(false));
        logger.w('Skipping Firebase initialization for this run (SKIP_FIREBASE_INIT=true).');
      }

      // Only truly-blocking tasks remain on the critical path.
      await Future.wait(<Future<Object?>>[PersistenceBootstrap.initialize(), _initializeMonitoring(sentryConfig)]);

      // Defer MobileAds and Analytics to after first frame. Resolves firebaseInitialized
      // lazily once Firebase background init completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          FirebaseInit.readyFuture.then(
            (firebaseInitialized) => _deferredStartup(firebaseInitialized: firebaseInitialized),
          ),
        );
      });

      await MonitoringRuntime.reporter.addBreadcrumb(
        message: 'Startup stage reached',
        category: 'app.startup.stage',
        data: <String, Object?>{'stage': 'persistence_initialized'},
      );
      DebugFlags.instance.loadFromStore();
      logger.d("Persistence initialized");

      // DI is not configured yet, so read the settings store directly.
      final settings = SettingsLocalDataSource(PersistenceRuntime.store);
      final themeMode = settings.get<String>('themeMode', defaultValue: 'Dark');
      final categories = settings.get<int>('WHcategories', defaultValue: 100);
      // App Store review: no sketchy content on iOS, regardless of the stored pref.
      final purity = defaultTargetPlatform == TargetPlatform.iOS
          ? 100
          : settings.get<int>('WHpurity', defaultValue: 100);

      // Accents saved by old builds are strings; rewrite them as ints so the theme repository can read them.
      await Future.wait(<Future<void>>[
        settings.set(
          'lightAccent',
          _colorValueFromPrefs(settings.get<Object?>('lightAccent'), fallback: prismDefaultAccentValue),
        ),
        settings.set(
          'darkAccent',
          _colorValueFromPrefs(settings.get<Object?>('darkAccent'), fallback: prismDefaultAccentValue),
        ),
        settings.set('optimisedWallpapers', settings.get<bool>('optimisedWallpapers', defaultValue: false)),
        settings.set('WHcategories', categories == 100 ? 100 : 111),
        settings.set('WHpurity', purity == 100 ? 100 : 110),
      ]);

      configureDependencies();
      await Future.wait(<Future<void>>[
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      ]);
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: themeMode == 'Light' ? Brightness.dark : Brightness.light);

      await FirebaseInit.readyFuture;

      await PurchasesService.instance.configureEarly();

      runApp(
        LogToastOverlay(
          child: RestartWidget(
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AdsBloc>(create: (_) => getIt<AdsBloc>()),
                BlocProvider<WallpaperDetailBloc>(create: (_) => getIt<WallpaperDetailBloc>()),
                BlocProvider<CategoryFeedBloc>(create: (_) => getIt<CategoryFeedBloc>()),
                BlocProvider<FavouriteWallsBloc>(create: (_) => getIt<FavouriteWallsBloc>()),
                BlocProvider<SessionBloc>(create: (_) => getIt<SessionBloc>()..add(const SessionEvent.started())),
                BlocProvider<StartupBloc>(
                  create: (_) =>
                      getIt<StartupBloc>()..add(StartupEvent.started(currentVersion: app_state.currentAppVersion)),
                ),
                BlocProvider<ThemeBloc>(create: (_) => getIt<ThemeBloc>()..add(const ThemeEvent.started())),
                BlocProvider<WotdBloc>(create: (_) => getIt<WotdBloc>()..add(const WotdEvent.started())),
              ],
              child: _MyApp(),
            ),
          ),
        ),
      );
    },
    (obj, stacktrace) {
      logger.e('Uncaught zone error', tag: 'ZoneError', error: obj, stackTrace: stacktrace);
      unawaited(analytics.track(const AppCrashFatalEvent()));
    },
  );
}

Future<void> _deferredStartup({required bool firebaseInitialized}) async {
  await MobileAds.instance.initialize();
  await _configureAnalyticsRuntime(firebaseInitialized: firebaseInitialized);
}

SentryConfig _resolveSentryConfig() {
  const String fallbackEnvironment = kReleaseMode ? 'production' : 'staging';
  final String fallbackRelease = 'Prism@${app_state.currentAppVersion}+${app_state.currentAppVersionCode}';
  return SentryConfig.fromEnvironment(
    fallbackEnvironment: fallbackEnvironment,
    fallbackRelease: fallbackRelease,
    fallbackDist: app_state.currentAppVersionCode,
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
      options.replay.sessionSampleRate = _sentryReplaySessionSampleRate;
      options.replay.onErrorSampleRate = _sentryReplayOnErrorSampleRate;
      options.privacy.maskAllText = true;
      options.privacy.maskAllImages = true;
      // Sentry turns on debug in debug builds, and then the iOS hang tracker
      // symbolicates with every thread suspended and can deadlock the app on
      // launch (getsentry/sentry-cocoa#5609). Release builds keep it.
      options.enableAppHangTracking = !kDebugMode;
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

Future<void> _configureAnalyticsRuntime({required bool firebaseInitialized}) async {
  final bool mixpanelEnabled = _isMixpanelEnabled();
  logger.i(
    'Analytics startup configuration resolved.',
    tag: 'Analytics',
    fields: <String, Object?>{
      'replay_backend': 'sentry',
      'sentry_replay_session_sample_rate': _sentryReplaySessionSampleRate,
      'sentry_replay_on_error_sample_rate': _sentryReplayOnErrorSampleRate,
      'mixpanel_enabled': mixpanelEnabled,
      'mixpanel_token_present': Env.normalize(Env.mixpanelToken).isNotEmpty,
    },
  );

  final List<AnalyticsProvider> providers = <AnalyticsProvider>[];

  final AnalyticsProvider? mixpanelProvider = await _buildMixpanelProvider(enabled: mixpanelEnabled);
  if (mixpanelProvider != null) {
    providers.add(mixpanelProvider);
  }

  if (firebaseInitialized) {
    providers.add(FirebaseAnalyticsProvider());
  }

  if (providers.isEmpty) {
    providers.add(const NoopAnalyticsProvider());
  }

  AnalyticsRuntime.instance = ProviderBackedAppAnalytics(provider: CompositeAnalyticsProvider(providers));
}

Future<AnalyticsProvider?> _buildMixpanelProvider({required bool enabled}) async {
  if (!enabled) {
    logger.i(
      'Mixpanel analytics disabled by configuration.',
      tag: 'Analytics',
      fields: <String, Object?>{
        'mixpanel_enabled': Env.normalize(Env.mixpanelEnabled).toLowerCase(),
        'mixpanel_token_present': Env.normalize(Env.mixpanelToken).isNotEmpty,
      },
    );
    return null;
  }

  final String token = Env.normalize(Env.mixpanelToken);
  if (token.isEmpty) {
    logger.w('MIXPANEL_ENABLED is on but MIXPANEL_TOKEN is empty. Skipping Mixpanel provider.', tag: 'Analytics');
    return null;
  }

  try {
    return await MixpanelAnalyticsProvider.create(token: token);
  } catch (error, stackTrace) {
    logger.w(
      'Mixpanel initialization failed; continuing with available analytics providers.',
      tag: 'Analytics',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

bool _isMixpanelEnabled() {
  final String rawValue = Env.normalize(Env.mixpanelEnabled).toLowerCase();
  if (rawValue.isEmpty || rawValue == 'auto') {
    return Env.normalize(Env.mixpanelToken).isNotEmpty;
  }

  return const <String>{'1', 'true', 'yes', 'on'}.contains(rawValue);
}

class _MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<_MyApp> with WidgetsBindingObserver {
  late final AppRouter _appRouter;
  late final AnalyticsIdentitySync _analyticsIdentitySync;
  final DeepLinkParser _deepLinkParser = const DeepLinkParser();
  final ShortLinkResolver _shortLinkResolver = ShortLinkResolver();
  final DeepLinkNavigation _deepLinkNavigation = const DeepLinkNavigation();
  final NotificationRouteMapper _notificationRouteMapper = const NotificationRouteMapper();
  final PendingDeepLinkQueue _pendingDeepLinks = PendingDeepLinkQueue();
  bool _bootstrapCompleted = false;
  static bool _launchLinkHandled = false;
  bool _coinSyncInFlight = false;
  static const Duration _coinSyncCooldown = Duration(seconds: 30);
  DateTime? _lastCoinSyncAt;

  Future<bool> _restoreLoginStatus() async {
    final bool value = await globalGoogleAuth.isSignedIn();
    if (!value) {
      // Ensure stale profile data from previous sessions cannot make the app behave as logged in.
      app_state.prismUser
        ..loggedIn = false
        ..premium = false
        ..subscriptionTier = 'free'
        ..id = ''
        ..email = ''
        ..username = ''
        ..name = ''
        ..bio = ''
        ..profilePhoto = app_state.defaultProfilePhotoUrl
        ..coverPhoto = ''
        ..followers = <String>[]
        ..following = <String>[]
        ..links = <String, String>{};
      clearInAppNotificationSyncGateAll();
    }
    app_state.prismUser.loggedIn = value;
    await _syncAnalyticsIdentityFromAppState(sourceTag: 'startup_login_status');
    // RevenueCat starts anonymous, so this also restores a guest's premium
    // entitlement (iOS 5.1.1(v)) after the signed-out reset above wiped it.
    // Coins require auth, so coin sync only runs for signed-in users.
    await PurchasesService.instance.checkAndPersistPremium();
    if (value) {
      unawaited(_syncCoinEconomy(sourceTag: 'startup_login_status'));
    }
    app_state.persistPrismUser();
    await syncSentryUserScope(
      loggedIn: app_state.prismUser.loggedIn,
      id: app_state.prismUser.id,
      email: app_state.prismUser.email,
      username: app_state.prismUser.username,
    );
    return value;
  }

  Future<void> _syncAnalyticsIdentity({
    required bool loggedIn,
    required String userId,
    required String subscriptionTier,
    required bool isPremium,
    required String sourceTag,
  }) {
    return _analyticsIdentitySync.sync(
      loggedIn: loggedIn,
      userId: userId,
      subscriptionTier: subscriptionTier,
      isPremium: isPremium,
      sourceTag: sourceTag,
    );
  }

  Future<void> _syncAnalyticsIdentityFromAppState({required String sourceTag}) {
    return _syncAnalyticsIdentity(
      loggedIn: app_state.prismUser.loggedIn,
      userId: app_state.prismUser.id,
      subscriptionTier: app_state.prismUser.subscriptionTier,
      isPremium: app_state.prismUser.premium,
      sourceTag: sourceTag,
    );
  }

  Future<void> _syncAnalyticsIdentityFromSession(SessionEntity session, {required String sourceTag}) {
    return _syncAnalyticsIdentity(
      loggedIn: session.loggedIn,
      userId: session.userId,
      subscriptionTier: session.subscriptionTier,
      isPremium: session.premium,
      sourceTag: sourceTag,
    );
  }

  /// Minimum time between coin syncs triggered by app resume to reduce Firestore reads/writes.
  static const Duration _coinSyncResumeThrottle = Duration(minutes: 10);
  DateTime? _lastCoinSyncResume;

  /// Throttle getNotifs on resume to avoid repeated queries with 0 results.
  static const Duration _getNotifsResumeThrottle = Duration(minutes: 5);
  DateTime? _lastGetNotifsResume;

  void _reloadInAppNotificationsFromCache() {
    if (!getIt.isRegistered<InAppNotificationsBloc>()) {
      return;
    }
    getIt<InAppNotificationsBloc>().add(const InAppNotificationsEvent.localReloadRequested());
  }

  Future<void> _syncCoinEconomy({required String sourceTag}) async {
    if (_coinSyncInFlight) {
      return;
    }
    if (!app_state.prismUser.loggedIn || app_state.prismUser.id.trim().isEmpty) {
      return;
    }
    final now = DateTime.now();
    if (_lastCoinSyncAt != null && now.difference(_lastCoinSyncAt!) < _coinSyncCooldown) {
      return;
    }
    _coinSyncInFlight = true;
    _lastCoinSyncAt = now;
    try {
      await CoinsService.instance.bootstrapForCurrentUser();
      // Skip redundant refreshBalance: bootstrap already reads usersv2 and applies balance locally.
      await CoinsService.instance.claimDailyLoginAndStreakIfEligible();
      await CoinsService.instance.maybeAwardProDailyBonus();
      await CoinsService.instance.processPendingReferralIfEligible();
    } catch (error, stackTrace) {
      CoinsService.instance.logCoinError(sourceTag: 'coins.main.$sourceTag', error: error, stackTrace: stackTrace);
    } finally {
      _coinSyncInFlight = false;
    }
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
      await localNotification.createNotificationChannel(
        "wall_of_the_day",
        "Wall of the Day",
        "Daily featured wallpaper notification at 9 AM.",
        true,
      );
      await localNotification.createNotificationChannel(
        "streak_reminder",
        "Streak reminders",
        "8 PM reminder to keep your login streak alive.",
        true,
      );
    } catch (e, st) {
      logger.w('Failed to configure local notification channels.', error: e, stackTrace: st);
    }
  }

  TargetTypeValue _deepLinkTargetType(DeepLinkActionEntity action) {
    return switch (action) {
      ShareLinkIntent() => TargetTypeValue.share,
      UserLinkIntent() => TargetTypeValue.user,
      SetupLinkIntent() => TargetTypeValue.setup,
      ReferLinkIntent() => TargetTypeValue.refer,
      ShortCodeIntent() => TargetTypeValue.shortCode,
      UnknownIntent() => TargetTypeValue.unknown,
    };
  }

  Future<void> _processPendingDeepLinks() async {
    if (!_bootstrapCompleted || _pendingDeepLinks.isEmpty) {
      return;
    }
    if (_appRouter.hasEntries && _appRouter.topRoute.name == SplashWidgetRoute.name) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_processPendingDeepLinks());
      });
      return;
    }
    await _pendingDeepLinks.drain(_handleDeepLinkIntent, ready: _bootstrapCompleted);
  }

  Future<void> _handleDeepLinkIntent(DeepLinkActionEntity action) async {
    switch (action) {
      case ShareLinkIntent():
        _appRouter.push(
          WallpaperDetailRoute(
            wallId: action.wallId,
            source: action.source,
            thumbnailUrl: action.thumbnailUrl,
            analyticsSurface: AnalyticsSurfaceValue.shareWallpaperView,
          ),
        );
        unawaited(
          analytics.track(
            const DeepLinkNavigationResultEvent(targetType: TargetTypeValue.share, result: EventResultValue.navigated),
          ),
        );
      case UserLinkIntent():
        _appRouter.push(ProfileRoute(profileIdentifier: action.profileIdentifier));
        unawaited(
          analytics.track(
            const DeepLinkNavigationResultEvent(targetType: TargetTypeValue.user, result: EventResultValue.navigated),
          ),
        );
      case SetupLinkIntent():
        _appRouter.navigate(const HomeTabRoute());
        toasts.error('Home screen setups are no longer available.');
        unawaited(
          analytics.track(
            const DeepLinkNavigationResultEvent(targetType: TargetTypeValue.setup, result: EventResultValue.navigated),
          ),
        );
      case ReferLinkIntent():
        if (action.inviterId.trim().isEmpty) {
          unawaited(
            analytics.track(
              const DeepLinkNavigationResultEvent(
                targetType: TargetTypeValue.refer,
                result: EventResultValue.failure,
                reason: AnalyticsReasonValue.missingData,
              ),
            ),
          );
          return;
        }
        unawaited(CoinsService.instance.setPendingReferralInviterId(action.inviterId));
        if (app_state.prismUser.loggedIn) {
          unawaited(CoinsService.instance.processPendingReferralIfEligible(inviterUserId: action.inviterId));
        } else {
          toasts.success('Referral saved. Sign in to claim +${CoinPolicy.referral} coins.');
        }
        unawaited(
          analytics.track(
            const DeepLinkNavigationResultEvent(targetType: TargetTypeValue.refer, result: EventResultValue.success),
          ),
        );
      case ShortCodeIntent():
        await _resolveAndNavigateShortCode(action.code);
      case UnknownIntent():
        _appRouter.push(const NotFoundRoute());
        unawaited(
          analytics.track(
            const DeepLinkNavigationResultEvent(
              targetType: TargetTypeValue.unknown,
              result: EventResultValue.failure,
              reason: AnalyticsReasonValue.unknown,
            ),
          ),
        );
    }
  }

  Future<DeepLink> _routerDeepLinkBuilder(PlatformDeepLink platformDeepLink) async {
    // RestartWidget rebuilds the router after logout and account deletion, and the platform still reports the link
    // the process was launched with. Replaying it would reopen that screen (or not-found) in the new session.
    if (platformDeepLink.initial) {
      if (_launchLinkHandled) return DeepLink.defaultPath;
      _launchLinkHandled = true;
    }
    final DeepLinkActionEntity action = _deepLinkParser.parse(platformDeepLink.uri);
    final TargetTypeValue targetType = _deepLinkTargetType(action);
    final bool isKnown = action is! UnknownIntent;

    unawaited(
      analytics.track(
        DeepLinkReceivedEvent(source: DeepLinkSourceValue.appLinks, targetType: targetType, hasPayload: isKnown),
      ),
    );
    unawaited(
      analytics.track(
        DeepLinkResolvedEvent(
          targetType: targetType,
          result: isKnown ? EventResultValue.success : EventResultValue.failure,
          reason: isKnown ? null : AnalyticsReasonValue.missingData,
        ),
      ),
    );

    if (isKnown) {
      _pendingDeepLinks.add(action);
      if (_bootstrapCompleted) {
        unawaited(_processPendingDeepLinks());
      }
      return platformDeepLink.initial ? DeepLink.defaultPath : DeepLink.none;
    }

    if (platformDeepLink.isValid) {
      return platformDeepLink;
    }

    if (platformDeepLink.uri.path.isNotEmpty && platformDeepLink.uri.path != '/') {
      _pendingDeepLinks.add(action);
      if (_bootstrapCompleted) {
        unawaited(_processPendingDeepLinks());
      }
    }
    return platformDeepLink.initial ? DeepLink.defaultPath : DeepLink.none;
  }

  Future<void> _resolveAndNavigateShortCode(String code) async {
    if (code.trim().isEmpty) {
      unawaited(
        analytics.track(
          const DeepLinkResolvedEvent(
            targetType: TargetTypeValue.shortCode,
            result: EventResultValue.failure,
            reason: AnalyticsReasonValue.emptyInput,
          ),
        ),
      );
      return;
    }

    switch (await _shortLinkResolver.resolve(code)) {
      case ShortLinkResolved(:final action):
        unawaited(
          analytics.track(
            const DeepLinkResolvedEvent(targetType: TargetTypeValue.shortCode, result: EventResultValue.success),
          ),
        );
        await _handleDeepLinkIntent(action);
      case ShortLinkFailed(:final reason):
        unawaited(
          analytics.track(
            DeepLinkResolvedEvent(
              targetType: TargetTypeValue.shortCode,
              result: EventResultValue.failure,
              reason: reason,
            ),
          ),
        );
        if (!await _shortLinkResolver.openFallback(code)) {
          _appRouter.navigate(const NotFoundRoute());
        }
    }
  }

  /// Routes a tapped push notification to the correct screen based on
  /// the `route` field in the notification's data payload.
  Future<void> _handlePushTap(Map<String, dynamic> data) async {
    final String route = data['route']?.toString() ?? '';
    final String wallId = (data['wall_id']?.toString() ?? '').trim();
    final String rawUrl = (data['url']?.toString() ?? '').trim();

    logger.i('Push tapped', tag: 'Push', fields: <String, Object?>{'route': route, 'wall_id': wallId, 'url': rawUrl});

    if (_isLegacySetupRoute(route)) {
      _queueDeepLink(SetupLinkIntent(rawUri: route));
      return;
    }
    if (route == 'wall_of_the_day') {
      unawaited(analytics.track(WotdOpenedFromPushEvent(wallId: wallId)));
    }

    if (rawUrl.isNotEmpty) {
      final Uri? parsed = Uri.tryParse(rawUrl);
      if (parsed != null && _deepLinkNavigation.isPrismDeepLink(parsed)) {
        final DeepLinkActionEntity action = _deepLinkParser.parse(_deepLinkParser.transform(parsed));
        if (action is SetupLinkIntent || action is ShortCodeIntent) {
          _queueDeepLink(action);
          return;
        }
        final PageRouteInfo? deepLinkRoute = await _deepLinkNavigation.mapUriToRoute(parsed);
        if (deepLinkRoute != null) {
          _appRouter.navigate(deepLinkRoute);
          return;
        }
      }
    }

    final PageRouteInfo? mappedRoute = await _notificationRouteMapper.fromPayload(data, sourceTag: 'push.route_mapper');
    if (mappedRoute != null) {
      _appRouter.navigate(mappedRoute);
      return;
    }
    _appRouter.navigate(const NotFoundRoute());
  }

  bool _isLegacySetupRoute(String route) {
    final Uri? uri = Uri.tryParse(route.trim());
    return uri != null && _deepLinkParser.parse(uri) is SetupLinkIntent;
  }

  void _queueDeepLink(DeepLinkActionEntity action) {
    _pendingDeepLinks.add(action);
    if (_bootstrapCompleted) {
      unawaited(_processPendingDeepLinks());
    }
  }

  Future<void> _listenForPushMessages() async {
    // Wait for Firebase to be ready before touching any Firebase APIs.
    final bool firebaseReady = await FirebaseInit.readyFuture;
    if (!firebaseReady) return;

    // Foreground: show a heads-up local notification + sync the inbox.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      unawaited(localNotification.showPushNotification(message));
      unawaited(syncInAppNotificationsFromRemote().then((_) => _reloadInAppNotificationsFromCache()));
    });

    // Background / terminated → foreground: user tapped the notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      unawaited(_handlePushTap(message.data));
    });

    // Launched from terminated state by tapping a notification.
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_handlePushTap(message.data));
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appRouter = AppRouter();
    localNotification.router = _appRouter;
    localNotification.onPushTap = _handlePushTap;
    _analyticsIdentitySync = AnalyticsIdentitySync(analytics: AnalyticsRuntime.instance);
    unawaited(_configureDisplayMode());
    unawaited(_configureLocalNotificationChannels());
    unawaited(_restoreLoginStatus());
    unawaited(localNotification.fetchNotificationData(context));
    unawaited(_listenForPushMessages());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastCoinSyncResume == null || now.difference(_lastCoinSyncResume!) >= _coinSyncResumeThrottle) {
        _lastCoinSyncResume = now;
        unawaited(_syncCoinEconomy(sourceTag: 'app_resumed'));
      }
      if (_lastGetNotifsResume == null || now.difference(_lastGetNotifsResume!) >= _getNotifsResumeThrottle) {
        _lastGetNotifsResume = now;
        unawaited(syncInAppNotificationsFromRemote().then((_) => _reloadInAppNotificationsFromCache()));
      }
      return;
    }
    if (state == AppLifecycleState.paused) {
      unawaited(analytics.flush());
    }
  }

  @override
  void dispose() {
    unawaited(analytics.flush());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionBloc, SessionState>(
          listenWhen: (previous, current) =>
              previous.session.userId != current.session.userId ||
              previous.session.loggedIn != current.session.loggedIn ||
              previous.session.subscriptionTier != current.session.subscriptionTier ||
              previous.session.premium != current.session.premium,
          listener: (context, state) {
            unawaited(_syncAnalyticsIdentityFromSession(state.session, sourceTag: 'session_bloc'));
          },
        ),
        BlocListener<SessionBloc, SessionState>(
          listenWhen: (previous, current) => previous.session.loggedIn && !current.session.loggedIn,
          listener: (context, state) {
            if (getIt.isRegistered<InAppNotificationsBloc>()) {
              getIt<InAppNotificationsBloc>().add(const InAppNotificationsEvent.clearRequested());
            }
          },
        ),
        BlocListener<StartupBloc, StartupState>(
          listenWhen: (previous, current) =>
              previous.status != current.status || previous.isObsoleteVersion != current.isObsoleteVersion,
          listener: (context, state) {
            if (state.status != LoadStatus.success || state.isObsoleteVersion) {
              return;
            }
            _bootstrapCompleted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_processPendingDeepLinks());
            });
          },
        ),
        // Cache WOTD URL for the Wall of the Day quick tile.
        BlocListener<WotdBloc, WotdState>(
          listenWhen: (previous, current) => previous.entity?.url != current.entity?.url && current.entity != null,
          listener: (context, state) {
            final url = state.entity?.url;
            if (url != null && url.isNotEmpty) {
              unawaited(QuickTileConfigService.pushWotdUrl(url));
            }
          },
        ),
        // Cache favourite wall URLs for the Random Favourite quick tile.
        BlocListener<FavouriteWallsBloc, FavouriteWallsState>(
          listenWhen: (previous, current) => previous.status != current.status && current.status == LoadStatus.success,
          listener: (context, state) {
            final urls = state.items.map((item) => item.fullUrl).toList(growable: false);
            unawaited(QuickTileConfigService.pushFavWallUrls(urls));
          },
        ),
      ],
      child: ListenableBuilder(
        listenable: DebugFlags.instance,
        builder: (context, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            app_state.notchSize = MediaQuery.paddingOf(context).top;
            return child ?? const SizedBox.shrink();
          },
          routerConfig: _appRouter.config(
            deepLinkTransformer: (uri) async => _deepLinkParser.transform(uri),
            deepLinkBuilder: _routerDeepLinkBuilder,
            navigatorObservers: () => [
              ...analytics.buildNavigatorObservers(),
              if (MonitoringRuntime.reporter.isEnabled)
                SentryNavigatorObserver(enableAutoTransactions: false, ignoreRoutes: <String>['/']),
            ],
          ),
          showPerformanceOverlay: DebugFlags.instance.showPerformanceOverlay,
          showSemanticsDebugger: DebugFlags.instance.showSemanticsDebugger,
          theme: context.prismLightTheme(),
          darkTheme: context.prismDarkTheme(),
          themeMode: context.prismThemeMode(),
        ),
      ),
    );
  }
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({this.child});
  final Widget? child;
  // ignore: unreachable_from_main
  static void restartApp(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: key, child: widget.child!);
  }
}
