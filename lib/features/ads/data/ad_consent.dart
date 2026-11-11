import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef ConsentStep = Future<void> Function();
typedef CanRequestAds = Future<bool> Function();
typedef PrivacyOptionsRequired = Future<bool> Function();
typedef TrackingRequest = Future<void> Function();

/// Google UMP consent. Ads load only after [ensure] returns true. It never throws.
class AdConsent {
  AdConsent({
    ConsentStep? requestInfoUpdate,
    ConsentStep? showFormIfRequired,
    CanRequestAds? canRequestAds,
    PrivacyOptionsRequired? privacyOptionsRequired,
    ConsentStep? showPrivacyOptions,
    TrackingRequest? requestTracking,
    this.updateTimeout = const Duration(seconds: 10),
    this.trackingTimeout = const Duration(seconds: 12),
  }) : _requestInfoUpdate = requestInfoUpdate ?? _platformRequestInfoUpdate,
       _showFormIfRequired = showFormIfRequired ?? _platformShowFormIfRequired,
       _canRequestAds = canRequestAds ?? ConsentInformation.instance.canRequestAds,
       _privacyOptionsRequired = privacyOptionsRequired ?? _platformPrivacyOptionsRequired,
       _showPrivacyOptions = showPrivacyOptions ?? _platformShowPrivacyOptions,
       _requestTracking = requestTracking ?? _platformRequestTracking;

  static AdConsent instance = AdConsent();

  final ConsentStep _requestInfoUpdate;
  final ConsentStep _showFormIfRequired;
  final CanRequestAds _canRequestAds;
  final PrivacyOptionsRequired _privacyOptionsRequired;
  final ConsentStep _showPrivacyOptions;
  final TrackingRequest _requestTracking;
  final Duration updateTimeout;
  final Duration trackingTimeout;

  Future<bool>? _pending;
  Future<bool>? _tracking;
  int generation = 0;
  bool privacyOptionsOpen = false;
  final Set<void Function()> invalidationListeners = <void Function()>{};

  /// Asks for App Tracking Transparency (iOS only). Every ad request waits for a terminal answer first.
  Future<bool> requestTracking() {
    final Future<bool> pending = _tracking ??= _askTracking().timeout(
      trackingTimeout,
      onTimeout: () {
        logger.w('Tracking permission request timed out.', tag: 'AdConsent');
        return false;
      },
    );
    unawaited(
      pending.then((bool allowed) {
        if (!allowed && identical(_tracking, pending)) _tracking = null;
      }),
    );
    return pending;
  }

  Future<bool> _askTracking() async {
    try {
      await _requestTracking();
      return true;
    } catch (error, stackTrace) {
      logger.w('Could not ask for tracking permission.', tag: 'AdConsent', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> canShow() async {
    try {
      final int before = generation;
      if (privacyOptionsOpen) return false;
      if (!await requestTracking()) return false;
      if (privacyOptionsOpen || before != generation) return false;
      final allowed = await _canRequestAds();
      return allowed && !privacyOptionsOpen && before == generation;
    } catch (_) {
      return false;
    }
  }

  /// Runs the consent flow once per session. A refused result is not kept, so the next call tries again.
  Future<bool> ensure() {
    if (privacyOptionsOpen) return Future<bool>.value(false);
    final Future<bool> pending = _pending ??= _run(generation);
    unawaited(
      pending.then((bool canRequest) {
        if (!canRequest && identical(_pending, pending)) _pending = null;
      }),
    );
    return pending;
  }

  /// True when the user must be able to reopen the consent choices, for example in the EEA and the UK.
  Future<bool> privacyOptionsRequired() async {
    try {
      return await _privacyOptionsRequired();
    } catch (error, stackTrace) {
      logger.w('Could not read the privacy options status.', tag: 'AdConsent', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Opens the UMP privacy options form. It never throws.
  Future<void> showPrivacyOptions() async {
    privacyOptionsOpen = true;
    _pending = null;
    generation++;
    for (final listener in invalidationListeners.toList()) {
      listener();
    }
    try {
      await _showPrivacyOptions();
    } catch (error, stackTrace) {
      logger.w('Could not show the privacy options.', tag: 'AdConsent', error: error, stackTrace: stackTrace);
    } finally {
      privacyOptionsOpen = false;
      _pending = null;
      generation++;
      for (final listener in invalidationListeners.toList()) {
        listener();
      }
    }
  }

  Future<bool> _run(int generationAtStart) {
    return PerformanceProbe.measure('startup', 'ad_consent', () async {
      if (!await requestTracking()) {
        unawaited(analytics.track(const AdConsentResultEvent(status: 'refused')));
        return false;
      }
      if (privacyOptionsOpen || generationAtStart != generation) {
        unawaited(analytics.track(const AdConsentResultEvent(status: 'refused')));
        return false;
      }

      try {
        await _requestInfoUpdate().timeout(updateTimeout);
        if (privacyOptionsOpen || generationAtStart != generation) {
          unawaited(analytics.track(const AdConsentResultEvent(status: 'refused')));
          return false;
        }
        await _showFormIfRequired();
      } catch (error, stackTrace) {
        logger.w(
          'Ad consent flow failed; using the stored consent.',
          tag: 'AdConsent',
          error: error,
          stackTrace: stackTrace,
        );
      }
      bool canRequest;
      try {
        canRequest = await _canRequestAds();
      } catch (error, stackTrace) {
        logger.w('Could not read ad consent.', tag: 'AdConsent', error: error, stackTrace: stackTrace);
        canRequest = false;
      }
      canRequest = canRequest && !privacyOptionsOpen && generationAtStart == generation;
      unawaited(analytics.track(AdConsentResultEvent(status: canRequest ? 'can_request' : 'refused')));
      return canRequest;
    });
  }

  static const MethodChannel _trackingChannel = MethodChannel('prism/tracking');

  static Future<void> _platformRequestTracking() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final String? status = await _trackingChannel.invokeMethod<String>('request');
    if (status == 'authorized' || status == 'denied' || status == 'restricted') return;
    throw StateError('Tracking permission did not reach a terminal status: $status');
  }

  static Future<bool> _platformPrivacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  static Future<void> _platformShowPrivacyOptions() {
    final Completer<void> completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(StateError('${error.errorCode}: ${error.message}'));
      }
    });
    return completer.future;
  }

  static Future<void> _platformRequestInfoUpdate() {
    final Completer<void> completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      completer.complete,
      (FormError error) => completer.completeError(StateError('${error.errorCode}: ${error.message}')),
    );
    return completer.future;
  }

  static Future<void> _platformShowFormIfRequired() {
    final Completer<void> completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(StateError('${error.errorCode}: ${error.message}'));
      }
    });
    return completer.future;
  }
}
