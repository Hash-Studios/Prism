import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_prizes.dart';
import 'package:Prism/features/spin_wheel/views/pages/spin_wheel_page.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_machine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The way into the machine on the Rewards page: a small still wheel, what a spin costs or pays, and a button.
/// [status] and [segments] default to today's live state; a test passes its own.
class SpinWheelCard extends StatelessWidget {
  const SpinWheelCard({super.key, this.status, this.segments, this.onOpen});

  final ValueListenable<SpinWheelStatus>? status;
  final List<WheelSegment>? segments;

  /// Defaults to [showSpinWheel].
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SpinWheelStatus>(
      valueListenable: status ?? CoinsService.instance.spinWheelNotifier,
      builder: (BuildContext context, SpinWheelStatus status, Widget? _) {
        final List<WheelSegment> wheel = segments ?? CoinPolicy.spinWheel;
        final VoidCallback open = onOpen ?? () => unawaited(showSpinWheel(context));
        final bool canSpin = status.canSpin;
        final String caption = !canSpin
            ? context.l10n.economyBackTomorrow
            : status.freeSpinAvailable
            ? context.l10n.economyFreeSpinReady(status.paidSpinsLeft)
            : context.l10n.economySpinCardCaption(status.price, maxWheelCoins(wheel));
        return PrismCard(
          onTap: open,
          semanticLabel: context.l10n.economySpinWheelCardSemantics(caption),
          child: Row(
            children: <Widget>[
              _MiniWheel(segments: wheel),
              const SizedBox(width: PrismSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(context.l10n.economySpinTheWheel, style: PrismTextStyles.cardTitle(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    Text(caption, style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
              if (canSpin) ...<Widget>[
                const SizedBox(width: PrismSpace.sm),
                PrismButton(
                  label: status.freeSpinAvailable ? context.l10n.economyFreeSpin : context.l10n.economySpin,
                  size: PrismButtonSize.compact,
                  onPressed: open,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A listenable that never changes: the mini wheel does not turn, glow or swing.
class _Still<T> implements ValueListenable<T> {
  const _Still(this.value);

  @override
  final T value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _MiniWheel extends StatelessWidget {
  const _MiniWheel({required this.segments});

  final List<WheelSegment> segments;

  static const double size = 72;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ExcludeSemantics(
        child: WheelMachine(
          segments: segments,
          geometry: const WheelGeometry(size),
          theta: _Still<double>(restAngle(segments.length)),
          flapper: const _Still<double>(0),
          bulbs: const _Still<BulbFrame>(BulbFrame()),
          showLabels: false,
        ),
      ),
    );
  }
}
