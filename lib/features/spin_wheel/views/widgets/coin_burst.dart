import 'dart:math' as math;

import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:flutter/material.dart';

/// Coins that fly out from the middle and fade. [animation] runs 0 to 1; [radius] is how far the farthest coin goes.
/// It paints nothing at rest, and the page skips it under reduced motion.
class CoinBurst extends StatelessWidget {
  const CoinBurst({super.key, required this.animation, required this.radius, this.count = 10});

  final Animation<double> animation;
  final double radius;
  final int count;

  /// Fixed seed for the jitter: the same burst every time, so a frame is reproducible.
  static const int _jitterSeed = 7;

  @override
  Widget build(BuildContext context) {
    final math.Random random = math.Random(_jitterSeed);
    final List<_Coin> coins = <_Coin>[
      for (int i = 0; i < count; i++)
        _Coin(
          angle: (i / count) * 2 * math.pi + (random.nextDouble() - 0.5) * 0.5,
          reach: 0.55 + 0.45 * random.nextDouble(),
          size: 20 + 10 * random.nextDouble(),
          delay: 0.06 * random.nextDouble(),
        ),
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? _) {
          final double t = animation.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[for (final _Coin coin in coins) _paint(coin, t)],
          );
        },
      ),
    );
  }

  Widget _paint(_Coin coin, double t) {
    final double local = ((t - coin.delay) / (1 - coin.delay)).clamp(0.0, 1.0);
    final double out = Curves.easeOutCubic.transform(local);
    final double distance = radius * coin.reach * out;
    final Offset offset = Offset(math.cos(coin.angle), math.sin(coin.angle)) * distance + Offset(0, 36 * local * local);
    final double fade = local < 0.55 ? 1 : 1 - (local - 0.55) / 0.45;
    final double scale = 0.55 + 0.45 * Curves.easeOut.transform(math.min(local * 3.5, 1)) - 0.15 * local;
    return Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: PrismCoinIcon(size: coin.size),
        ),
      ),
    );
  }
}

class _Coin {
  const _Coin({required this.angle, required this.reach, required this.size, required this.delay});

  final double angle;
  final double reach;
  final double size;
  final double delay;
}
