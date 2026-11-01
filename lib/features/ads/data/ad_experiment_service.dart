import 'dart:convert';
import 'dart:math';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/data/ad_experiment_policy.dart';
import 'package:Prism/features/ads/data/ad_sdk.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State shared by ad formats. Call impression methods only from SDK impression callbacks.
class AdExperimentService with WidgetsBindingObserver {
  AdExperimentService();

  static final AdExperimentService instance = AdExperimentService();
  static const String _seedKey = 'ad_experiment.install_seed';
  static const String _fullscreenKey = 'ad_experiment.last_fullscreen';
  static const String _interstitialDayKey = 'ad_experiment.interstitial_day';
  static const String _sessionKey = 'ad_experiment.session';
  AdExperimentConfig config = AdExperimentConfig.disabled;
  int nativeImpressions = 0;
  int bannerImpressions = 0;
  bool _successfulWallpaperAction = false;
  Future<String?>? _seed;
  Future<void>? _starting;
  Future<void> _lifecycleWrites = Future<void>.value();
  bool _backgrounded = false;
  bool _storageHealthy = false;
  DateTime? _lastFullscreenMemory;
  String? _interstitialDayMemory;
  final Set<AdExperimentFormat> _inlineClaims = <AdExperimentFormat>{};

  bool claimInline(AdExperimentFormat format) {
    if (format == AdExperimentFormat.interstitial) return false;
    if (format == AdExperimentFormat.native && nativeImpressions > 0) return false;
    if (format == AdExperimentFormat.banner && bannerImpressions > 0) return false;
    return _inlineClaims.add(format);
  }

  void releaseInline(AdExperimentFormat format) => _inlineClaims.remove(format);

  Stream<void> watchEligibilityChanges() => getIt.isRegistered<SessionRepository>()
      ? getIt<SessionRepository>().watchCurrentUser().map((_) {})
      : const Stream<void>.empty();

  Future<void> start() => _starting ??= _start();

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  Future<void> _start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _completePreviousSession(prefs, DateTime.now());
      _storageHealthy = true;
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // Missing persistence leaves eligibility unknown.
    }
  }

  Future<void> _completePreviousSession(SharedPreferences prefs, DateTime now) async {
    final state = _session(prefs);
    nativeImpressions = state['native']! as int;
    bannerImpressions = state['banner']! as int;
    final int? background = state['background'] as int?;
    if (background == null) return;
    final DateTime then = DateTime.fromMillisecondsSinceEpoch(background);
    int count = state['count']! as int;
    if (!now.isBefore(then) && now.difference(then) >= const Duration(minutes: 30)) {
      count++;
      nativeImpressions = 0;
      bannerImpressions = 0;
    }
    await _writeSession(prefs, count, null);
  }

  Map<String, Object?> _session(SharedPreferences prefs) {
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return <String, Object?>{'count': 0, 'background': null, 'native': 0, 'banner': 0};
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['count'] is! int ||
        (decoded['count'] as int) < 0 ||
        (decoded['background'] != null && decoded['background'] is! int)) {
      throw const FormatException('Invalid ad session');
    }
    for (final key in ['native', 'banner']) {
      if (decoded[key] != null && (decoded[key] is! int || (decoded[key] as int) < 0)) {
        throw const FormatException('Invalid ad impression count');
      }
    }
    return <String, Object?>{
      'count': decoded['count'],
      'background': decoded['background'],
      'native': decoded['native'] ?? 0,
      'banner': decoded['banner'] ?? 0,
    };
  }

  Future<void> _writeSession(SharedPreferences prefs, int count, int? background) async {
    if (!await prefs.setString(
      _sessionKey,
      jsonEncode(<String, Object?>{
        'count': count,
        'background': background,
        'native': nativeImpressions,
        'banner': bannerImpressions,
      }),
    )) {
      throw StateError('Could not persist ad session');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_backgrounded) {
      _backgrounded = true;
      final int at = DateTime.now().millisecondsSinceEpoch;
      _lifecycleWrites = _lifecycleWrites
          .then((_) async {
            final prefs = await SharedPreferences.getInstance();
            await _writeSession(prefs, _session(prefs)['count']! as int, at);
          })
          .catchError((Object _) {
            _storageHealthy = false;
          });
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      final now = DateTime.now();
      _lifecycleWrites = _lifecycleWrites
          .then((_) async {
            final prefs = await SharedPreferences.getInstance();
            await _completePreviousSession(prefs, now);
          })
          .catchError((Object _) {
            _storageHealthy = false;
          });
    }
  }

  Future<void> initializeAds() => initializeMobileAds();

  Future<bool> permits(AdExperimentFormat format, {required bool active, bool action = false}) async {
    if (!active || !config.enabled(format)) return false;
    try {
      await start();
      await _lifecycleWrites;
      if (!_storageHealthy) return false;
      final prefs = await SharedPreferences.getInstance();
      if (!getIt.isRegistered<SessionRepository>() ||
          !getIt.isRegistered<SettingsLocalDataSource>() ||
          !getIt.isRegistered<FirestoreClient>()) {
        return false;
      }
      final settings = getIt<SettingsLocalDataSource>();
      if (!settings.isOpen) return false;
      final String? requestedUserId = FirebaseAuth.instance.currentUser?.uid;
      if (requestedUserId == null || requestedUserId.isEmpty) return false;
      final bool confirmedFree = await getIt<FirestoreClient>()
          .runTransaction<bool>(
            (transaction) async {
              final data = await transaction.getDoc(FirebaseCollections.usersV2, requestedUserId);
              return data?['premium'] == false && data?['subscriptionTier'] == 'free';
            },
            sourceTag: 'ad_experiment.eligibility',
            collection: FirebaseCollections.usersV2,
            docId: requestedUserId,
          )
          .timeout(const Duration(seconds: 3));
      if (!confirmedFree) return false;
      final int consentGeneration = AdConsent.instance.generation;
      final consent = await AdConsent.instance.canShow();
      final int? assignment = await bucket();
      final bool shownToday = await interstitialShownToday();
      final DateTime? fullscreen = await lastFullscreen();
      if (consentGeneration != AdConsent.instance.generation) return false;
      final user = app_state.prismUser;
      final String? firebaseUserId = FirebaseAuth.instance.currentUser?.uid;
      return const AdExperimentPolicy().permits(
        config: config,
        format: format,
        bucket: assignment,
        eligibility: AdExperimentEligibility(
          completedSessions: _session(prefs)['count']! as int,
          isFree:
              firebaseUserId != null &&
              firebaseUserId == requestedUserId &&
              firebaseUserId == user.id &&
              user.loggedIn &&
              !user.premium &&
              user.subscriptionTier == 'free',
          consentAllowed: consent,
          activePlacement: active,
          onboardingComplete: settings.get<bool>(OnboardingV2Keys.onboardedNew, defaultValue: false),
        ),
        sessionImpressions: format == AdExperimentFormat.native ? nativeImpressions : bannerImpressions,
        interstitialShownToday: shownToday,
        successfulWallpaperAction: action,
        lastFullscreen: fullscreen,
        now: DateTime.now(),
      );
    } catch (_) {
      return false;
    }
  }

  void applyConfig(String raw) => config = AdExperimentConfig.parse(raw);

  /// The install seed and account ID determine a stable local assignment.
  Future<int?> bucket({String? accountId}) async {
    final id = accountId ?? FirebaseAuth.instance.currentUser?.uid;
    if (config.version.isEmpty || id == null || id.isEmpty) return null;
    final String? seed = await (_seed ??= _loadSeed());
    return seed == null ? null : bucketFor('$seed:$id', config.version);
  }

  Future<String?> _loadSeed() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? seed = prefs.getString(_seedKey);
      if (seed == null || seed.isEmpty) {
        final Random random = Random.secure();
        seed = List<int>.generate(
          16,
          (_) => random.nextInt(256),
        ).map((int x) => x.toRadixString(16).padLeft(2, '0')).join();
        if (!await prefs.setString(_seedKey, seed)) return null;
      }
      return seed;
    } catch (_) {
      return null;
    }
  }

  static int bucketFor(String seed, String version) {
    int hash = 0x811c9dc5;
    for (final int byte in '$seed:$version'.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash % 100;
  }

  void recordSuccessfulWallpaperAction() => _successfulWallpaperAction = true;

  /// Consume only on a deliberate return to browsing, even if no ad is available.
  bool consumeSuccessfulWallpaperAction() {
    final bool result = _successfulWallpaperAction;
    _successfulWallpaperAction = false;
    return result;
  }

  Future<void> recordInlineImpression(AdExperimentFormat format) {
    if (format == AdExperimentFormat.native) nativeImpressions++;
    if (format == AdExperimentFormat.banner) bannerImpressions++;
    return _lifecycleWrites = _lifecycleWrites
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          final state = _session(prefs);
          await _writeSession(prefs, state['count']! as int, state['background'] as int?);
        })
        .catchError((Object _) {
          _storageHealthy = false;
        });
  }

  Future<void> recordFullscreen({DateTime? at}) async {
    final DateTime now = at ?? DateTime.now();
    _lastFullscreenMemory = now;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!await prefs.setInt(_fullscreenKey, now.millisecondsSinceEpoch)) {
        throw StateError('Could not persist fullscreen cap');
      }
    } catch (_) {
      _storageHealthy = false;
      rethrow;
    }
  }

  Future<void> recordInterstitialImpression({DateTime? at}) async {
    final DateTime now = at ?? DateTime.now();
    _interstitialDayMemory = _day(now);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_interstitialDayKey, _day(now))) {
        throw StateError('Could not persist interstitial cap');
      }
      await recordFullscreen(at: now);
    } catch (_) {
      _storageHealthy = false;
      rethrow;
    }
  }

  Future<DateTime?> lastFullscreen() async {
    final int? value = (await SharedPreferences.getInstance()).getInt(_fullscreenKey);
    final DateTime? stored = value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
    final DateTime? memory = _lastFullscreenMemory;
    if (memory == null) return stored;
    return stored == null || memory.isAfter(stored) ? memory : stored;
  }

  Future<bool> interstitialShownToday({DateTime? at}) async =>
      _interstitialDayMemory == _day(at ?? DateTime.now()) ||
      (await SharedPreferences.getInstance()).getString(_interstitialDayKey) == _day(at ?? DateTime.now());

  static String _day(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year}-${utc.month}-${utc.day}';
  }
}
