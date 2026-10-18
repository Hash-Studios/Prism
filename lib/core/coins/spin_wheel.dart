import 'package:Prism/core/utils/json_utils.dart';

/// What one slice of the wheel pays. Mirrors `WheelSegment` in functions/src/economy.ts.
sealed class WheelPrize {
  const WheelPrize();
}

final class CoinsPrize extends WheelPrize {
  const CoinsPrize(this.coins);

  final int coins;
}

final class XpPrize extends WheelPrize {
  const XpPrize(this.xp);

  final int xp;
}

/// A random unowned common cosmetic, or [fallbackCoins] when the user already owns every one.
final class CosmeticPrize extends WheelPrize {
  const CosmeticPrize({required this.fallbackCoins});

  final int fallbackCoins;
}

class WheelSegment {
  const WheelSegment(this.prize, {required this.weight});

  final WheelPrize prize;
  final double weight;

  /// The JSON shape the server stores in `award.spinWheel` and returns in a spin reply.
  static WheelSegment? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> m = toJsonMap(raw);
    final Object? weight = m['weight'];
    if (weight is! num || !weight.isFinite || weight < 0 || weight > _maxAward) return null;
    final WheelPrize? prize = switch (m['kind']) {
      'coins' => switch (_amount(m['coins'], min: 1)) {
        final int c => CoinsPrize(c),
        _ => null,
      },
      'xp' => switch (_amount(m['xp'], min: 1)) {
        final int xp => XpPrize(xp),
        _ => null,
      },
      'cosmetic' => switch (_amount(m['fallbackCoins'], min: 0)) {
        final int c => CosmeticPrize(fallbackCoins: c),
        _ => null,
      },
      _ => null,
    };
    return prize == null ? null : WheelSegment(prize, weight: weight.toDouble());
  }
}

const int _maxAward = 1000;
const int minWheelSegments = 2;
const int maxWheelSegments = 12;

/// A whole number in `min..1000`, the same bound as `isAward` on the server.
int? _amount(Object? raw, {required int min}) {
  if (raw is! num || !raw.isFinite || raw != raw.truncate()) return null;
  final int value = raw.toInt();
  return value >= min && value <= _maxAward ? value : null;
}

/// Parses a wheel table, or returns null when any segment is malformed, the count is out of range or no weight is
/// positive. The caller falls back to [defaultWheel].
List<WheelSegment>? parseWheel(Object? raw) {
  if (raw is! List || raw.length < minWheelSegments || raw.length > maxWheelSegments) return null;
  final List<WheelSegment> segments = <WheelSegment>[];
  for (final Object? s in raw) {
    final WheelSegment? segment = WheelSegment.fromMap(s);
    if (segment == null) return null;
    segments.add(segment);
  }
  final double total = segments.fold<double>(0, (double sum, WheelSegment s) => sum + s.weight);
  return total > 0 ? List<WheelSegment>.unmodifiable(segments) : null;
}

/// Same order and odds as `DEFAULT_ECONOMY.award.spinWheel` on the server. Index 0 sits under the pointer at rest.
const List<WheelSegment> defaultWheel = <WheelSegment>[
  WheelSegment(CoinsPrize(10), weight: 18),
  WheelSegment(XpPrize(25), weight: 22),
  WheelSegment(CoinsPrize(5), weight: 30),
  WheelSegment(CoinsPrize(100), weight: 1),
  WheelSegment(CoinsPrize(20), weight: 8),
  WheelSegment(XpPrize(50), weight: 12),
  WheelSegment(CoinsPrize(50), weight: 3),
  WheelSegment(CosmeticPrize(fallbackCoins: 50), weight: 6),
];

/// Today's spin state for the signed-in user, from `private/economy.spinWheel` and the spin replies.
class SpinWheelStatus {
  const SpinWheelStatus({required this.freeSpinAvailable, required this.paidSpinsLeft, required this.price});

  /// Pro members get one free spin per UTC day.
  final bool freeSpinAvailable;
  final int paidSpinsLeft;

  /// What a paid spin costs.
  final int price;

  /// What the next spin costs. The client sends it as `maxCost`, so the server never charges more than this.
  int get nextCost => freeSpinAvailable ? 0 : price;

  bool get canSpin => freeSpinAvailable || paidSpinsLeft > 0;
}

/// What the user got from a landed spin. Cosmetic fallback coins arrive as [coins] with a null [itemId].
class WheelWin {
  const WheelWin({required this.segment, this.coins = 0, this.xp = 0, this.itemId});

  /// Index into the reply's segments that the wheel must land on.
  final int segment;
  final int coins;
  final int xp;
  final String? itemId;
}

enum SpinRefusal { insufficientBalance, dailyLimit, priceChanged }

sealed class SpinWheelResult {
  const SpinWheelResult();
}

final class SpinWon extends SpinWheelResult {
  const SpinWon({required this.win, required this.cost, required this.segments, required this.status});

  final WheelWin win;

  /// What this spin cost, 0 for the Pro free spin.
  final int cost;

  /// The table the server spun. Land on this, not on the cached config.
  final List<WheelSegment> segments;
  final SpinWheelStatus status;
}

final class SpinRefused extends SpinWheelResult {
  const SpinRefused(this.refusal, {required this.status});

  final SpinRefusal refusal;
  final SpinWheelStatus status;
}

/// No definite reply. A retry replays the same request id, so the server never spins twice for one tap.
final class SpinFailed extends SpinWheelResult {
  const SpinFailed(this.reason);

  final String reason;
}
