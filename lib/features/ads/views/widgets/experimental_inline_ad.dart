import 'dart:async';
import 'dart:io';

import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/data/ad_experiment_service.dart';
import 'package:Prism/features/ads/data/ad_experiment_telemetry.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Placed in a lazy sliver so a request starts only near the viewport.
class ExperimentalInlineAd extends StatefulWidget {
  const ExperimentalInlineAd({
    required this.format,
    required this.active,
    this.availableWidth,
    this.service,
    this.android,
    this.loadAd,
    super.key,
  });

  final AdExperimentFormat format;
  final bool active;
  final double? availableWidth;
  final AdExperimentService? service;
  final bool? android;
  final Future<void> Function(AdWithView ad)? loadAd;

  @override
  State<ExperimentalInlineAd> createState() => _ExperimentalInlineAdState();
}

class _ExperimentalInlineAdState extends State<ExperimentalInlineAd> with WidgetsBindingObserver {
  AdWithView? _ad;
  AdSize? _size;
  bool _loaded = false;
  bool _attempted = false;
  bool _claimed = false;
  int _generation = 0;
  int? _bucket;
  String _version = '';
  StreamSubscription<void>? _sessionSubscription;
  AdExperimentService get _service => widget.service ?? AdExperimentService.instance;

  String get _placement => widget.format == AdExperimentFormat.native ? 'for_you' : 'rewards';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdConsent.instance.invalidationListeners.add(_consentChanged);
    _sessionSubscription = _service.watchEligibilityChanges().listen((_) {
      if (!mounted) return;
      _invalidate();
      _sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ExperimentalInlineAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    } else if (state == AppLifecycleState.paused) {
      _invalidate();
    }
  }

  bool get _active =>
      mounted &&
      widget.active &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  void _consentChanged() {
    _invalidate();
    if (!AdConsent.instance.privacyOptionsOpen) _sync();
  }

  void _invalidate() {
    _generation++;
    if (_claimed) _service.releaseInline(widget.format);
    _claimed = false;
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _attempted = false;
    if (mounted) setState(() {});
  }

  void _sync() {
    if (!_active) {
      if (_ad != null || _attempted) _invalidate();
      return;
    }
    if (_attempted) return;
    _attempted = true;
    unawaited(_load(++_generation));
  }

  void _event(String outcome, {double? value, String? currency, String? precision}) {
    final bucket = _bucket;
    if (bucket == null) return;
    trackAdExperiment(
      AdExperimentEvent(
        placement: _placement,
        format: widget.format,
        bucket: bucket,
        version: _version,
        outcome: outcome,
        valueMicros: value,
        currency: currency,
        precision: precision,
      ),
    );
  }

  Future<void> _load(int generation) async {
    final service = _service;
    if (widget.android == null && !Platform.isAndroid && !Platform.isIOS) return;
    if (!await service.permits(widget.format, active: true)) return;
    try {
      await service.initializeAds();
    } catch (_) {
      return;
    }
    final config = service.config;
    final id = config.unitId(widget.format, android: widget.android ?? Platform.isAndroid);
    if (id.isEmpty) return;
    final bucket = await service.bucket();
    if (!mounted || generation != _generation || !_active || bucket == null) return;
    _bucket = bucket;
    _version = config.version;
    Future<void> loaded(Ad ad) async {
      if (!mounted || generation != _generation || !_active || !await service.permits(widget.format, active: true)) {
        ad.dispose();
        return;
      }
      if (!mounted || generation != _generation || !_active) {
        ad.dispose();
        return;
      }
      if (ad is BannerAd) _size = await ad.getPlatformAdSize();
      if (!mounted || generation != _generation || !_active) {
        ad.dispose();
        return;
      }
      if (ad is BannerAd && _size == null) {
        ad.dispose();
        return;
      }
      if (!service.claimInline(widget.format)) {
        ad.dispose();
        if (identical(_ad, ad)) _ad = null;
        return;
      }
      _claimed = true;
      _event('loaded');
      setState(() => _loaded = true);
    }

    void failed(Ad ad, LoadAdError error) {
      if (generation != _generation || !mounted) {
        ad.dispose();
        return;
      }
      _event('no_fill');
      ad.dispose();
      if (identical(_ad, ad)) _ad = null;
    }

    void impression(Ad ad) {
      if (!mounted || generation != _generation || !_active || !identical(_ad, ad)) return;
      unawaited(service.recordInlineImpression(widget.format));
      _event('impression');
    }

    void paid(Ad ad, double value, PrecisionType precision, String currency) {
      if (!mounted || generation != _generation || !_active || !identical(_ad, ad)) return;
      _event('paid', value: value, precision: precision.name, currency: currency);
    }

    final AdWithView ad;
    if (widget.format == AdExperimentFormat.native) {
      ad = NativeAd(
        adUnitId: id,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.medium),
        listener: NativeAdListener(
          onAdLoaded: (ad) => unawaited(loaded(ad)),
          onAdFailedToLoad: failed,
          onAdImpression: impression,
          onPaidEvent: paid,
        ),
      );
    } else if (widget.format == AdExperimentFormat.banner) {
      final width = (widget.availableWidth ?? MediaQuery.sizeOf(context).width).floor();
      if (width <= 0) return;
      ad = BannerAd(
        adUnitId: id,
        request: const AdRequest(),
        size: AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(width),
        listener: BannerAdListener(
          onAdLoaded: (ad) => unawaited(loaded(ad)),
          onAdFailedToLoad: failed,
          onAdImpression: impression,
          onPaidEvent: paid,
        ),
      );
    } else {
      return;
    }
    _ad = ad;
    _event('requested');
    try {
      await (widget.loadAd?.call(ad) ?? ad.load());
    } catch (_) {
      if (identical(_ad, ad)) _ad = null;
      ad.dispose();
      _event('failed');
    }
  }

  @override
  void dispose() {
    AdConsent.instance.invalidationListeners.remove(_consentChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sessionSubscription?.cancel());
    _generation++;
    if (_claimed) _service.releaseInline(widget.format);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null || !_active) return const SizedBox.shrink();
    final size = _size;
    final Widget view = SizedBox(
      width: size?.width.toDouble() ?? double.infinity,
      height: size?.height.toDouble() ?? 320,
      child: AdWidget(ad: ad),
    );
    if (widget.format != AdExperimentFormat.native) return view;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(context.l10n.economyAd, style: Theme.of(context).textTheme.labelSmall),
        ),
        view,
      ],
    );
  }
}

class DeferredAdSliver extends StatefulWidget {
  const DeferredAdSliver({required this.child, super.key});

  final Widget child;

  @override
  State<DeferredAdSliver> createState() => _DeferredAdSliverState();
}

class _DeferredAdSliverState extends State<DeferredAdSliver> {
  bool _reached = false;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      _reached = _reached || (constraints.remainingCacheExtent > 0 && constraints.scrollOffset == 0);
      return SliverToBoxAdapter(child: _reached ? widget.child : const SizedBox.shrink());
    },
  );
}
