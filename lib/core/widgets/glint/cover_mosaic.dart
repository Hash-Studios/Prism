import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Bundled covers that read as wallpapers (abstracts, skies, night scenes, nature). 12, so the 3 tiles each cycle
/// through their own 4 and never show the same cover twice.
const List<String> kCoverMosaicAssets = <String>[
  'assets/images/covers/1269968.webp',
  'assets/images/covers/3052361.webp',
  'assets/images/covers/3560044.webp',
  'assets/images/covers/1616403.webp',
  'assets/images/covers/572897.webp',
  'assets/images/covers/807598.webp',
  'assets/images/covers/3169299.webp',
  'assets/images/covers/844297.webp',
  'assets/images/covers/747964.webp',
  'assets/images/covers/31687154.webp',
  'assets/images/covers/301614.webp',
  'assets/images/covers/355288.webp',
];

/// A stable start index for [seed]. `String.hashCode` is not stable across runs, so captures would change.
@visibleForTesting
int coverMosaicStart(String seed) {
  int hash = 0;
  for (final int unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % kCoverMosaicAssets.length;
}

/// A collage of 3 bundled wallpaper covers: one tall tile at the start, two stacked at the end (3 columns in a box
/// more than twice as wide as it is tall). 12 point corners, 4 point gaps. Every 6 seconds one tile crossfades to its next cover; under reduce motion it holds still.
///
/// It fills its box, so the caller sizes it. The covers come from [seed] (a page title), so a page always opens on
/// the same art. An optional [badge] (Glint, the logo) sits on a surface ring over the bottom-end corner and hangs
/// [badgeOverhang] below the art; the widget's height includes that overhang.
///
/// The art is decoration, so screen readers skip it.
class CoverMosaic extends StatefulWidget {
  const CoverMosaic({super.key, required this.seed, this.badge, this.badgeOverhang = 20});

  final String seed;
  final Widget? badge;
  final double badgeOverhang;

  static const Duration interval = Duration(seconds: 6);
  static const Duration crossfade = Duration(milliseconds: 1200);

  @override
  State<CoverMosaic> createState() => _CoverMosaicState();
}

class _CoverMosaicState extends State<CoverMosaic> {
  static const int _tiles = 3;
  Timer? _timer;
  int _ticks = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(CoverMosaic.interval, (_) {
        // Hidden routes keep their state; only move while on screen.
        if (mounted && TickerMode.valuesOf(context).enabled) setState(() => _ticks++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Tile [tile] has moved `(ticks - tile + 2) ~/ 3` times; each move steps 3 covers, so tiles never collide.
  String _asset(int tile) {
    final int moves = (_ticks + _tiles - 1 - tile) ~/ _tiles;
    return kCoverMosaicAssets[(coverMosaicStart(widget.seed) + tile + _tiles * moves) % kCoverMosaicAssets.length];
  }

  Widget _tile(int tile) {
    final String asset = _asset(tile);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PrismRadius.sm),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: AnimatedSwitcher(
          duration: CoverMosaic.crossfade,
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          layoutBuilder: (Widget? current, List<Widget> previous) =>
              Stack(fit: StackFit.expand, children: <Widget>[...previous, if (current != null) current]),
          child: Image.asset(
            asset,
            key: ValueKey<String>(asset),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double gap = PrismSpace.xxs;
    final Widget art = ExcludeSemantics(
      child: LayoutBuilder(
        // A wide banner gets 3 columns, so the tiles stay close to portrait.
        builder: (BuildContext context, BoxConstraints box) => box.maxWidth > box.maxHeight * 2
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _tile(0)),
                  const SizedBox(width: gap),
                  Expanded(child: _tile(1)),
                  const SizedBox(width: gap),
                  Expanded(child: _tile(2)),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _tile(0)),
                  const SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: _tile(1)),
                        const SizedBox(height: gap),
                        Expanded(child: _tile(2)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
    final Widget? badge = widget.badge;
    if (badge == null) return art;
    return Stack(
      children: <Widget>[
        Positioned.fill(bottom: widget.badgeOverhang, child: art),
        PositionedDirectional(
          end: PrismSpace.sm,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle),
            child: Padding(padding: const EdgeInsets.all(PrismSpace.xxs), child: badge),
          ),
        ),
      ],
    );
  }
}
