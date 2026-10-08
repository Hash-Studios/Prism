import 'dart:async';

import 'package:Prism/logger/logger.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef ConsentStep = Future<void> Function();
typedef CanRequestAds = Future<bool> Function();

/// Google UMP consent. Ads load only after [ensure] returns true. It never throws.
class AdConsent {
  AdConsent({
    ConsentStep? requestInfoUpdate,
    ConsentStep? showFormIfRequired,
    CanRequestAds? canRequestAds,
    this.updateTimeout = const Duration(seconds: 10),
  }) : _requestInfoUpdate = requestInfoUpdate ?? _platformRequestInfoUpdate,
       _showFormIfRequired = showFormIfRequired ?? _platformShowFormIfRequired,
       _canRequestAds = canRequestAds ?? ConsentInformation.instance.canRequestAds;

  static final AdConsent instance = AdConsent();

  final ConsentStep _requestInfoUpdate;
  final ConsentStep _showFormIfRequired;
  final CanRequestAds _canRequestAds;
  final Duration updateTimeout;

  Future<bool>? _pending;

  /// Runs the consent flow once per session. A refused result is not kept, so the next call tries again.
  Future<bool> ensure() {
    final Future<bool> pending = _pending ??= _run();
    unawaited(
      pending.then((bool canRequest) {
        if (!canRequest && identical(_pending, pending)) _pending = null;
      }),
    );
    return pending;
  }

  Future<bool> _run() async {
    try {
      await _requestInfoUpdate().timeout(updateTimeout);
      await _showFormIfRequired();
    } catch (error, stackTrace) {
      logger.w(
        'Ad consent flow failed; using the stored consent.',
        tag: 'AdConsent',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      return await _canRequestAds();
    } catch (error, stackTrace) {
      logger.w('Could not read ad consent.', tag: 'AdConsent', error: error, stackTrace: stackTrace);
      return false;
    }
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
