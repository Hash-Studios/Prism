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
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/debug/bloc_debug_observer.dart';
import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/debug/log_toast_overlay.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/flutter_error_handler.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_before_send.dart';
import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/bootstrap/persistence_bootstrap.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/deep_link_startup_gate.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/router/short_link_retry.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/startup/notification_channels.dart';
import 'package:Prism/core/startup/session_end_watcher.dart';
import 'package:Prism/core/startup/session_ended_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/orientation_policy.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/views/widgets/auto_rotate_session_listener.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/features/category_feed/category_feed.dart';
import 'package:Prism/features/favourite_walls/favourite_walls.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_quick_tile_listener.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/ios_shortcuts/views/widgets/shortcuts_favourites_listener.dart';
import 'package:Prism/features/quick_tiles/data/quick_tile_defaults.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/features/startup/services/resume_refresh_policy.dart';
import 'package:Prism/features/startup/startup.dart';
import 'package:Prism/features/theme_mode/data/theme_mode_migration.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/views/widgets/wotd_quick_tile_listener.dart';
import 'package:Prism/firebase_options.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/local_notification.dart';
import 'package:Prism/notifications/notification_signals.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      PerformanceProbe.mark('startup.binding_ready');
      HttpsCallable.perfSink = (String name, int ms, bool ok) =>
          PerformanceProbe.emit(kind: 'callable', name: name, durationMs: ms, success: ok);
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
        unawaited(analytics.track(const AppErrorEvent(errorSource: 'platform_dispatcher')));
        return true;
      };
      installFlutterFrameworkErrorHandler();

      const skipFirebaseInit = bool.fromEnvironment('SKIP_FIREBASE_INIT');
      final SentryConfig sentryConfig = _resolveSentryConfig();

      // Start Firebase early so it can initialize while persistence and monitoring run.
      // StartupRepositoryImpl.bootstrap() also awaits this future before accessing Remote Config.
      if (!skipFirebaseInit) {
        FirebaseInit.setFuture(
          PerformanceProbe.measure(
            'startup',
            'firebase_init',
            () => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).then((_) => true),
          ).catchError((Object e, StackTrace s) {
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
      await PerformanceProbe.measure(
        'startup',
        'persistence_and_monitoring',
        () => Future.wait(<Future<Object?>>[PersistenceBootstrap.initialize(), _initializeMonitoring(sentryConfig)]),
      );

      // Defer MobileAds and Analytics to after first frame. Resolves firebaseInitialized
      // lazily once Firebase background init completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(PurchasesService.instance.configureEarly());
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
      final String? migratedThemeMode = initialThemeModeToStore(
        storedMode: settings.get<Object?>('themeMode'),
        hasLegacyMarker: settings.get<Object?>('WHcategories') != null,
      );
      if (migratedThemeMode != null) await settings.set('themeMode', migratedThemeMode);
      final themeMode = settings.get<String>('themeMode', defaultValue: 'System');
      PrismHaptics.enabled = settings.get<bool>(PrismHaptics.settingsKey, defaultValue: true);
      final categories = settings.get<int>('WHcategories', defaultValue: 100);
      // App Store review: no sketchy content on iOS, regardless of the stored pref.
      final purity = defaultTargetPlatform == TargetPlatform.iOS
          ? 100
          : settings.get<int>('WHpurity', defaultValue: 100);

      // Accents saved by old builds are strings; rewrite them as ints so the theme repository can read them.
      await Future.wait(<Future<void>>[
        _setIfChanged(
          settings,
          'lightAccent',
          _colorValueFromPrefs(settings.get<Object?>('lightAccent'), fallback: prismDefaultAccentValue),
        ),
        _setIfChanged(
          settings,
          'darkAccent',
          _colorValueFromPrefs(settings.get<Object?>('darkAccent'), fallback: prismDefaultAccentValue),
        ),
        _setIfChanged(settings, 'optimisedWallpapers', settings.get<bool>('optimisedWallpapers', defaultValue: false)),
        _setIfChanged(settings, 'WHcategories', categories == 100 ? 100 : 110),
        _setIfChanged(settings, 'WHpurity', purity == 100 ? 100 : 110),
      ]);
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(QuickTileDefaults.mirrorWallhavenCategories(settings));
      }

      PerformanceProbe.mark('startup.before_di');
      configureDependencies();
      PerformanceProbe.mark('startup.di_ready');
      // The session repository has loaded persisted identity; set private notification stores before runApp reads them.
      final persistedUser = app_state.prismUser;
      final notificationOwner = persistedUser.loggedIn && persistedUser.id.trim().isNotEmpty
          ? persistedUser.id
          : 'guest';
      getIt<NotificationsLocalDataSource>().setOwner(notificationOwner);
      getIt<NotificationTombstones>().setOwner(notificationOwner);
      await Future.wait(<Future<void>>[
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        applyAllowedOrientations(),
      ]);
      final bool lightChrome =
          themeMode == 'Light' ||
          (themeMode == 'System' && PlatformDispatcher.instance.platformBrightness == Brightness.light);
      applyEdgeToEdgeOverlayStyle(statusBarIconBrightness: lightChrome ? Brightness.dark : Brightness.light);

      PerformanceProbe.mark('startup.run_app');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerformanceProbe.mark('startup.first_frame');
      });
      runApp(
        LogToastOverlay(
          child: BlocProvider<AutoRotateBloc>(
            create: (_) => getIt<AutoRotateBloc>(),
            child: RestartWidget(
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<AdsBloc>(create: (_) => getIt<AdsBloc>()),
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
                child: AutoRotateSessionListener(child: _MyApp()),
              ),
            ),
          ),
        ),
      );
    },
    (obj, stacktrace) {
      logger.e('Uncaught zone error', tag: 'ZoneError', error: obj, stackTrace: stacktrace);
      unawaited(analytics.track(const AppErrorEvent(errorSource: 'zone')));
    },
  );
}

Future<void> _setIfChanged(SettingsLocalDataSource settings, String key, Object value) {
  if (settings.get<Object?>(key) == value) return Future<void>.value();
  return settings.set(key, value);
}

Future<void> _deferredStartup({required bool firebaseInitialized}) async {
  unawaited(
    AdConsent.instance.ensure().then((bool canRequestAds) {
      if (canRequestAds) unawaited(MobileAds.instance.initialize());
    }),
  );
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
      options.beforeSend = dropNetworkNoise;
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
  late final OrientationPolicyObserver _orientationPolicyObserver;
  final AnalyticsIdentitySync _analyticsIdentitySync = AnalyticsIdentitySync();
  final DeepLinkParser _deepLinkParser = const DeepLinkParser();
  late final DeepLinkDispatcher _deepLinkDispatcher;
  late final AuthNavigationContinuation _authContinuation;
  final Map<String, (ShortCodeIntent, DeepLinkSourceValue)> _shortLinkRetries =
      <String, (ShortCodeIntent, DeepLinkSourceValue)>{};
  int _nextShortLinkRetry = 0;
  late final DeepLinkStartupGate _startupGate;
  late final ShortLinkRetryScheduler _shortLinkRetry;
  SessionEndWatcher? _sessionWatcher;
  static bool _launchLinkHandled = false;
  bool _coinSyncInFlight = false;
  static const Duration _coinSyncCooldown = Duration(seconds: 30);
  DateTime? _lastCoinSyncAt;

  Future<bool> _restoreLoginStatus() async {
    if (!await FirebaseInit.readyFuture) return app_state.prismUser.loggedIn;
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
    // Coins require auth, so coin sync only runs for signed-in users.
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
    // RevenueCat starts anonymous, so this also restores a guest's premium entitlement (iOS 5.1.1(v)) after the
    // signed-out reset above wiped it. It runs last and with a limit, so a slow RevenueCat never holds up the rest.
    unawaited(
      PurchasesService.instance.checkAndPersistPremium().timeout(const Duration(seconds: 8)).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        logger.w('Premium check at startup failed.', tag: 'Startup', error: error, stackTrace: stackTrace);
        return app_state.prismUser.premium;
      }),
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

  void _onAnalyticsRuntimeChanged() {
    unawaited(_syncAnalyticsIdentityFromAppState(sourceTag: 'analytics_runtime_ready'));
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
  DateTime? _lastWotdRefresh = DateTime.now();

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
      await CoinsService.instance.processPendingReferralIfEligible();
      await getIt<BadgeRepository>().check();
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
      await createNotificationChannels(localNotification.flutterLocalNotificationsPlugin);
    } catch (e, st) {
      logger.w('Failed to configure local notification channels.', error: e, stackTrace: st);
    }
  }

  Future<DeepLink> _routerDeepLinkBuilder(PlatformDeepLink platformDeepLink) async {
    // Router rebuilds after logout must not replay the process launch link.
    if (platformDeepLink.initial) {
      if (platformDeepLink.uri.path == '/' && platformDeepLink.uri.query.isEmpty) return DeepLink.defaultPath;
      if (_launchLinkHandled) return DeepLink.defaultPath;
      _launchLinkHandled = true;
    }
    unawaited(_deepLinkDispatcher.openUri(platformDeepLink.uri, source: DeepLinkSourceValue.appLinks));
    return platformDeepLink.initial ? DeepLink.defaultPath : DeepLink.none;
  }

  Future<void> _handleSessionEnded() async {
    try {
      _authContinuation.cancel();
      await globalGoogleAuth.signOutGoogle();
      final BuildContext? context = _appRouter.navigatorKey.currentContext;
      if (!mounted || context == null || !context.mounted) return;
      unawaited(showSessionEndedSheet(context, onSignedIn: () => RestartWidget.restartApp(context)));
    } catch (error, stackTrace) {
      logger.w('Session ended handling failed.', tag: 'Session', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _watchSession() async {
    if (!await FirebaseInit.readyFuture || !mounted) return;
    _sessionWatcher = SessionEndWatcher(
      idTokenChanges: FirebaseAuth.instance.idTokenChanges(),
      isLoggedIn: () => app_state.prismUser.loggedIn,
      onSessionEnded: _handleSessionEnded,
    )..start();
  }

  Future<void> _handlePushTap(Map<String, dynamic> data) async {
    await _deepLinkDispatcher.openPush(data);
  }

  Future<void> _listenForPushMessages() async {
    // Wait for Firebase to be ready before touching any Firebase APIs.
    final bool firebaseReady = await FirebaseInit.readyFuture;
    if (!firebaseReady) return;

    // Foreground messages and taps on background pushes. It calls the callbacks set in initState.
    localNotification.listenForPushMessages();

    // Launched from terminated state by tapping a notification.
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
          if (message == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_handlePushTap(message.data));
          });
        })
        .catchError((Object error, StackTrace stackTrace) {
          logger.w('Reading the launch push failed.', tag: 'Push', error: error, stackTrace: stackTrace);
        });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orientationPolicyObserver = OrientationPolicyObserver();
    unawaited(_orientationPolicyObserver.start());
    _appRouter = AppRouter();
    _authContinuation = AuthNavigationContinuation.of(_appRouter);
    _startupGate = DeepLinkStartupGate(router: _appRouter);
    _deepLinkDispatcher = DeepLinkDispatcher(
      router: _appRouter,
      whenReady: _startupGate.whenReady,
      whenBootstrapped: _startupGate.whenBootstrapped,
      onRetryNeeded: (action, source) {
        final String ticket = '${_nextShortLinkRetry++}';
        _shortLinkRetries[ticket] = (action, source);
        _shortLinkRetry.schedule(ticket);
      },
    );
    _shortLinkRetry = ShortLinkRetryScheduler(
      onlineChanges: () => getIt<ConnectivityService>().onConnectionChange,
      hasConnection: () => getIt<ConnectivityService>().hasConnection(),
      retry: (String ticket) {
        final request = _shortLinkRetries.remove(ticket);
        if (request == null) return;
        unawaited(_deepLinkDispatcher.openAction(request.$1, source: request.$2, isRetry: true));
      },
    );
    NotificationRouteMapper.onMeasuredTap = NotificationSignals.instance.onTap;
    localNotification
      ..onPushTap = _handlePushTap
      ..onForegroundPush = () =>
          unawaited(syncInAppNotificationsFromRemote().then((_) => _reloadInAppNotificationsFromCache()));
    toasts.overlayResolver = () => _appRouter.navigatorKey.currentState?.overlay;
    AnalyticsRuntime.changes.addListener(_onAnalyticsRuntimeChanged);
    unawaited(_configureDisplayMode());
    unawaited(_configureLocalNotificationChannels());
    unawaited(
      CoinsService.instance.restoreLocalEconomyForCurrentUser().catchError((Object error, StackTrace stackTrace) {
        CoinsService.instance.logCoinError(sourceTag: 'coins.main.local_restore', error: error, stackTrace: stackTrace);
      }),
    );
    unawaited(
      _restoreLoginStatus().catchError((Object error, StackTrace stackTrace) {
        logger.w('Restoring the login status failed.', tag: 'Startup', error: error, stackTrace: stackTrace);
        return false;
      }),
    );
    unawaited(
      localNotification.fetchNotificationData().catchError((Object error, StackTrace stackTrace) {
        logger.w('Reading the launch notification failed.', tag: 'Push', error: error, stackTrace: stackTrace);
      }),
    );
    unawaited(_listenForPushMessages());
    unawaited(_watchSession());
    unawaited(NotificationSignals.instance.onResumed());
  }

  Future<void> _refreshWotdTopics() async {
    try {
      if (!await FirebaseInit.readyFuture) return;
      await refreshWotdTopics(FirebaseMessaging.instance, getIt<SettingsLocalDataSource>());
    } catch (error, stackTrace) {
      logger.w('Wall of the Day topic refresh failed.', tag: 'Push', error: error, stackTrace: stackTrace);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      // The app can stay alive across days, so pick up a new Wall of the Day.
      if (shouldRefreshWotdOnResume(lastRefresh: _lastWotdRefresh, now: now)) {
        _lastWotdRefresh = now;
        context.read<WotdBloc>().add(const WotdEvent.started());
      }
      unawaited(_refreshWotdTopics());
      unawaited(NotificationSignals.instance.onResumed());
      unawaited(_shortLinkRetry.onResumed());
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
    AnalyticsRuntime.changes.removeListener(_onAnalyticsRuntimeChanged);
    _deepLinkDispatcher.dispose();
    _authContinuation.dispose();
    _startupGate.dispose();
    _shortLinkRetry.dispose();
    _sessionWatcher?.dispose();
    unawaited(analytics.flush());
    _orientationPolicyObserver.dispose();
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
          listenWhen: (previous, current) =>
              previous.session.loggedIn &&
              (!current.session.loggedIn || previous.session.userId != current.session.userId),
          listener: (context, state) {
            _authContinuation.cancel();
            _deepLinkDispatcher.cancel();
            _shortLinkRetry.dispose();
            _shortLinkRetries.clear();
          },
        ),
        BlocListener<SessionBloc, SessionState>(
          listenWhen: (previous, current) =>
              previous.session.userId != current.session.userId ||
              previous.session.loggedIn != current.session.loggedIn,
          listener: (context, state) {
            final ownerId = state.session.loggedIn && state.session.userId.trim().isNotEmpty
                ? state.session.userId
                : 'guest';
            getIt<NotificationsLocalDataSource>().setOwner(ownerId);
            getIt<NotificationTombstones>().setOwner(ownerId);
            clearInAppNotificationSyncGateAll();
            if (getIt.isRegistered<InAppNotificationsBloc>()) {
              getIt<InAppNotificationsBloc>().add(const InAppNotificationsEvent.localReloadRequested());
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
            _startupGate.markBootstrapCompleted();
            _authContinuation.markBootstrapCompleted();
          },
        ),
      ],
      child: WotdQuickTileListener(
        child: ShortcutsFavouritesListener(
          child: FavouriteQuickTileListener(
            child: ListenableBuilder(
              listenable: DebugFlags.instance,
              builder: (context, _) => MaterialApp.router(
                debugShowCheckedModeBanner: false,
                builder: (context, child) {
                  app_state.notchSize = MediaQuery.paddingOf(context).top;
                  final ThemeData theme = Theme.of(context);
                  final bool wide = MediaQuery.sizeOf(context).width > PrismLayout.panelWidth;
                  return Theme(
                    data: theme.copyWith(
                      snackBarTheme: theme.snackBarTheme.copyWith(width: wide ? PrismLayout.panelWidth : null),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                routerConfig: _appRouter.config(
                  deepLinkTransformer: (uri) async => _deepLinkParser.transform(uri),
                  deepLinkBuilder: _routerDeepLinkBuilder,
                  navigatorObservers: () => [
                    ...AnalyticsRuntime.buildNavigatorObservers(),
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
          ),
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
