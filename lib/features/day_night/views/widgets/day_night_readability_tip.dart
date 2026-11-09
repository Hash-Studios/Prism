import 'dart:async';
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/readability/data/readability_render.dart';
import 'package:Prism/features/readability/data/readability_tips.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/readability/views/readability_views.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The readability tip under one day or night wall. It checks the zones of the pair's [target] and offers the fix.
class DayNightReadabilityTip extends StatefulWidget {
  const DayNightReadabilityTip({super.key, required this.slot, required this.wall, required this.target});

  @visibleForTesting
  static Future<Map<ReadabilityZone, ReadabilityResult>> Function(
    ReadabilityKey key,
    Future<ui.Image> Function() decode,
  )?
  checkOverride;

  @visibleForTesting
  static Future<bool?> Function(BuildContext context, ReadabilityPreviewSource source, ReadabilityFix fix)?
  sheetOverride;

  final DayNightSlot slot;
  final DayNightWall wall;
  final WallpaperTarget target;

  @override
  State<DayNightReadabilityTip> createState() => _DayNightReadabilityTipState();
}

class _DayNightReadabilityTipState extends State<DayNightReadabilityTip> {
  static const Color _clockText = Color(0xFFFFFFFF);

  Map<ReadabilityZone, ReadabilityResult>? _result;
  late bool _tipsOn = _eligible;
  final Set<ReadabilityZone> _tracked = <ReadabilityZone>{};
  int _generation = 0;
  Timer? _timeout;

  bool get _eligible => ReadabilityTips.instance.enabled && !ReadabilityTips.instance.shownFor(widget.wall.id);

  ImageProvider get _provider => CachedNetworkImageProvider(widget.wall.thumbnailUrl);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_result == null) unawaited(_check());
  }

  @override
  void didUpdateWidget(DayNightReadabilityTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wall.id == widget.wall.id && oldWidget.wall.thumbnailUrl == widget.wall.thumbnailUrl) return;
    _generation++;
    _result = null;
    _tracked.clear();
    _timeout?.cancel();
    _tipsOn = _eligible;
    unawaited(_check());
  }

  @override
  void dispose() {
    _generation++;
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_tipsOn || widget.wall.thumbnailUrl.trim().isEmpty) return;
    final int generation = ++_generation;
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 2), () {
      if (mounted && generation == _generation && _result == null) setState(() => _tipsOn = false);
    });
    final Size screen = MediaQuery.sizeOf(context);
    if (screen.isEmpty) return;
    final int frameHeight = (analysisWidth * screen.longestSide / screen.shortestSide).round();
    final ImageProvider provider = _provider;
    try {
      final ReadabilityKey key = (
        wall: widget.wall.id,
        image: widget.wall.thumbnailUrl,
        placement: null,
        tint: null,
        platform: defaultTargetPlatform,
        clockText: _clockText.toARGB32(),
        frameHeight: frameHeight,
      );
      final Map<ReadabilityZone, ReadabilityResult> result =
          await (DayNightReadabilityTip.checkOverride ?? ReadabilityTips.instance.check)(
            key,
            () => decodeForFrame(provider, frameHeight * 2),
          );
      if (mounted && generation == _generation) setState(() => _result = result);
    } catch (error, stackTrace) {
      logger.w('Day and night: readability check failed', error: error, stackTrace: stackTrace);
    } finally {
      if (generation == _generation) _timeout?.cancel();
    }
  }

  /// The first busy zone the target shows that has no fix yet.
  ReadabilityZone? get _zone {
    final List<ReadabilityZone> zones = switch (widget.target) {
      WallpaperTarget.lock => const <ReadabilityZone>[ReadabilityZone.clock],
      WallpaperTarget.home => const <ReadabilityZone>[ReadabilityZone.icons],
      WallpaperTarget.both => ReadabilityZone.values,
    };
    for (final ReadabilityZone zone in zones) {
      final bool busy = _result?[zone]?.busy ?? false;
      if (busy && !widget.wall.fixes.any((fix) => fix.zone == zone)) return zone;
    }
    return null;
  }

  void _track(ReadabilityZone zone) {
    if (!_tracked.add(zone)) return;
    ReadabilityTips.instance.markShown(widget.wall.id);
    analytics.track(ReadabilityTipShownEvent(zone: zone));
  }

  Future<void> _open(ReadabilityZone zone) async {
    final ReadabilityFixKind? kind = _result?[zone]?.fix;
    if (kind == null) return;
    final int generation = _generation;
    final String wallId = widget.wall.id;
    final DayNightSlot slot = widget.slot;
    final WallpaperTarget target = widget.target;
    final ReadabilityFix fix = ReadabilityFix(zone, kind);
    final DayNightBloc bloc = context.read<DayNightBloc>();
    final Future<bool?> Function(BuildContext, ReadabilityPreviewSource, ReadabilityFix) showSheet =
        DayNightReadabilityTip.sheetOverride ?? showReadabilityFixSheet;
    final bool? apply = await showSheet(
      context,
      ReadabilityPreviewSource(provider: _provider, screen: MediaQuery.sizeOf(context), textColor: _clockText),
      fix,
    );
    if (!mounted ||
        generation != _generation ||
        wallId != widget.wall.id ||
        slot != widget.slot ||
        target != widget.target) {
      return;
    }
    if (apply == false) analytics.track(ReadabilityFixKeptEvent(zone: zone));
    if (apply != true) return;
    bloc.add(DayNightEvent.fixesChanged(slot, <ReadabilityFix>[...widget.wall.fixes, fix]));
    analytics.track(ReadabilityFixAppliedEvent(zone: zone, fixKind: kind));
  }

  @override
  Widget build(BuildContext context) {
    final ReadabilityZone? zone = _tipsOn ? _zone : null;
    if (zone == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _track(zone));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: ReadabilityChip(key: ValueKey<ReadabilityZone>(zone), zone: zone, onTap: () => _open(zone)),
      ),
    );
  }
}
