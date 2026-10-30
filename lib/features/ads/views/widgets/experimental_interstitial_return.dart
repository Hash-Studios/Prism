import 'dart:async';
import 'dart:io';

import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/data/ad_experiment_service.dart';
import 'package:Prism/features/ads/data/ad_experiment_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Owns one preload for a detail route opened from a wallpaper grid.
class ExperimentalInterstitialReturn extends StatefulWidget {
  const ExperimentalInterstitialReturn({
    required this.grid,
    required this.child,
    this.service,
    this.android,
    this.loadAd,
    super.key,
  });

  final BuildContext grid;
  final Widget child;
  final AdExperimentService? service;
  final bool? android;
  final Future<void> Function(String id, InterstitialAdLoadCallback callback)? loadAd;

  @override
  State<ExperimentalInterstitialReturn> createState() => _ExperimentalInterstitialReturnState();
}

class _ExperimentalInterstitialReturnState extends State<ExperimentalInterstitialReturn> with WidgetsBindingObserver {
  AdExperimentService get _service => widget.service ?? AdExperimentService.instance;
  InterstitialAd? _ad;
  int _generation = 0;
  int? _bucket;
  String _version = '';
  bool _returning = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service.consumeSuccessfulWallpaperAction();
    AdConsent.instance.invalidationListeners.add(_invalidate);
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _active =>
      mounted &&
      !_returning &&
      ModalRoute.of(context)?.isCurrent == true &&
      TickerMode.valuesOf(context).enabled &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  void _sync() {
    // After the pop, _showAfterReturn owns the ad and rechecks the grid itself.
    if (_returning) return;
    if (!_active) {
      _invalidate();
    } else if (!_loading && _ad == null) {
      unawaited(_preload());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _invalidate() {
    _generation++;
    _loading = false;
    _ad?.dispose();
    _ad = null;
  }

  void _event(String outcome, {double? value, String? currency, String? precision}) {
    final bucket = _bucket;
    if (bucket == null) return;
    trackAdExperiment(
      AdExperimentEvent(
        placement: 'return_to_browse',
        format: AdExperimentFormat.interstitial,
        bucket: bucket,
        version: _version,
        outcome: outcome,
        valueMicros: value,
        currency: currency,
        precision: precision,
      ),
    );
  }

  Future<void> _preload() async {
    _loading = true;
    final generation = _generation;
    if (widget.android == null && !Platform.isAndroid && !Platform.isIOS) return;
    if (!await _service.permits(AdExperimentFormat.interstitial, active: true, action: true)) return;
    try {
      await _service.initializeAds();
    } catch (_) {
      return;
    }
    final config = _service.config;
    final id = config.unitId(AdExperimentFormat.interstitial, android: widget.android ?? Platform.isAndroid);
    final bucket = await _service.bucket();
    if (!_active || generation != _generation || id.isEmpty || bucket == null) return;
    _bucket = bucket;
    _version = config.version;
    _event('requested');
    try {
      final callback = InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!_active || generation != _generation) {
            ad.dispose();
            return;
          }
          _ad = ad;
          _event('loaded');
        },
        onAdFailedToLoad: (_) => _event('no_fill'),
      );
      await (widget.loadAd?.call(id, callback) ??
          InterstitialAd.load(adUnitId: id, request: const AdRequest(), adLoadCallback: callback));
    } catch (_) {
      _event('failed');
    }
  }

  Future<void> _showAfterReturn() async {
    final ad = _ad;
    _ad = null;
    if (ad == null) {
      AdConsent.instance.invalidationListeners.remove(_invalidate);
      return;
    }
    final generation = _generation;
    final grid = widget.grid;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (generation != _generation ||
        !grid.mounted ||
        ModalRoute.of(grid)?.isCurrent != true ||
        !TickerMode.valuesOf(grid).enabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !await _service.permits(AdExperimentFormat.interstitial, active: true, action: true) ||
        generation != _generation ||
        !grid.mounted ||
        ModalRoute.of(grid)?.isCurrent != true ||
        !TickerMode.valuesOf(grid).enabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      AdConsent.instance.invalidationListeners.remove(_invalidate);
      ad.dispose();
      return;
    }
    AdConsent.instance.invalidationListeners.remove(_invalidate);
    ad.onPaidEvent = (_, value, precision, currency) =>
        _event('paid', value: value, precision: precision.name, currency: currency);
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) => unawaited(_service.recordFullscreen().catchError((Object _) {})),
      onAdImpression: (_) {
        unawaited(_service.recordInterstitialImpression().catchError((Object _) {}));
        _event('impression');
      },
      onAdDismissedFullScreenContent: (ad) => ad.dispose(),
      onAdFailedToShowFullScreenContent: (ad, _) {
        _event('failed_to_show');
        ad.dispose();
      },
    );
    try {
      await ad.show();
    } catch (_) {
      _event('failed_to_show');
      ad.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_returning) {
      AdConsent.instance.invalidationListeners.remove(_invalidate);
      _invalidate();
      _service.consumeSuccessfulWallpaperAction();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop || _returning) return;
      _returning = true;
      if (_service.consumeSuccessfulWallpaperAction()) {
        unawaited(_showAfterReturn());
      } else {
        AdConsent.instance.invalidationListeners.remove(_invalidate);
        _invalidate();
      }
    },
    child: widget.child,
  );
}
