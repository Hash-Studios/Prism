import 'dart:async';

import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/features/daily_chest/domain/chest_accent.dart';
import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:Prism/features/daily_chest/domain/chest_tiers.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_span.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

const String chestAsset = 'assets/lottie/daily_chest.json';

/// The fill keypaths the asset exposes: `glow` takes the tier colour, the `accent_*` layers take the user accent.
const List<String> chestGlowKeyPath = <String>['**', 'glow', '**'];
const List<String> chestAccentLightKeyPath = <String>['**', 'accent_light', '**'];
const List<String> chestAccentMidKeyPath = <String>['**', 'accent_mid', '**'];
const List<String> chestAccentDarkKeyPath = <String>['**', 'accent_dark', '**'];

/// The animated box. It plays the span of [phase] from the Lottie file: a loop, or once, or one held frame.
///
/// The prize shows from [onBurst], the frame where the light leaves the box. [onOpened] fires when the `open` span
/// ends. A box that is [still], or one under reduced motion, never ticks and shows one frame, so neither callback fires.
class ChestBox extends StatefulWidget {
  const ChestBox({
    super.key,
    required this.phase,
    this.size,
    this.glow,
    this.still = false,
    this.onBurst,
    this.onOpened,
  });

  final ChestPhase phase;

  /// Width and height. Null fills the parent.
  final double? size;

  /// The glow colour. Common while the chest is closed; the tier colour once the server has named the prize.
  final Color? glow;
  final bool still;
  final VoidCallback? onBurst;
  final VoidCallback? onOpened;

  @override
  State<ChestBox> createState() => _ChestBoxState();
}

class _ChestBoxState extends State<ChestBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)..addListener(_onTick);
  LottieComposition? _composition;
  (ChestPhase, bool)? _applied;
  double? _burstAt;
  bool _burstFired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ChestBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Plays what [ChestBox.phase] asks for, once per change of phase or of motion.
  void _sync() {
    final bool still = widget.still || context.reduceMotion;
    if (_applied == (widget.phase, still)) return;
    _applied = (widget.phase, still);
    _controller.stop();
    _burstAt = null;
    _burstFired = false;
    final ChestMarker marker = chestMarkers[widget.phase]!;
    if (still || marker.playback == ChestPlayback.hold) {
      final ChestMarker stillMarker = chestMarkers[chestStillPhase(widget.phase)]!;
      _controller.value = ChestSpan.of(stillMarker, _composition).at(stillMarker, stillMarker.stillFrame);
      return;
    }
    final ChestSpan span = ChestSpan.of(marker, _composition);
    _controller.value = span.from;
    if (marker.burstFrame != null) _burstAt = span.at(marker, marker.burstFrame!);
    switch (marker.playback) {
      case ChestPlayback.loop:
        unawaited(_controller.repeat(min: span.from, max: span.to, period: span.duration));
      case ChestPlayback.once:
        unawaited(
          _controller.animateTo(span.to, duration: span.duration).then((_) {
            if (mounted && widget.phase == ChestPhase.opening) widget.onOpened?.call();
          }),
        );
      case ChestPlayback.hold:
        break;
    }
  }

  void _onTick() {
    final double? at = _burstAt;
    if (at == null || _burstFired || !_controller.isAnimating || _controller.value < at) return;
    _burstFired = true;
    widget.onBurst?.call();
  }

  void _onLoaded(LottieComposition composition) {
    _composition = composition;
    _applied = null;
    _sync();
  }

  LottieDelegates _delegates(ColorScheme scheme) {
    final ChestAccent? accent = chestAccentOf(scheme.primary);
    return LottieDelegates(
      values: <ValueDelegate>[
        ValueDelegate.color(chestGlowKeyPath, value: widget.glow ?? ChestTier.common.color),
        if (accent != null) ...<ValueDelegate>[
          ValueDelegate.color(chestAccentLightKeyPath, value: accent.light),
          ValueDelegate.color(chestAccentMidKeyPath, value: accent.mid),
          ValueDelegate.color(chestAccentDarkKeyPath, value: accent.dark),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          chestAsset,
          controller: _controller,
          delegates: _delegates(Theme.of(context).colorScheme),
          onLoaded: _onLoaded,
          fit: BoxFit.contain,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
