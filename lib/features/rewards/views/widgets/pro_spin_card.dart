import 'dart:math';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// The daily Pro spin. Pro members get a card with a Spin button. Everyone else gets one quiet row to the paywall.
class ProSpinCard extends StatelessWidget {
  const ProSpinCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (app_state.prismUser.premium) return const _SpinCard();
    final range = proSpinRange();
    return PrismGroup(
      children: <Widget>[
        PrismRow(
          icon: Icons.workspace_premium_outlined,
          title: 'Pro members spin daily for ${range.low} to ${range.high} coins',
          onTap: () => PaywallOrchestrator.instance.presentOrRequireSignIn(
            context,
            placement: PaywallPlacement.mainUpsell,
            source: 'rewards_pro_spin_row',
          ),
        ),
      ],
    );
  }
}

/// The smallest and the largest coin amount on the Pro spin wheel.
({int low, int high}) proSpinRange() {
  final List<int> coins = CoinPolicy.proSpin.map((SpinSegment s) => s.coins).toList();
  return (low: coins.reduce(min), high: coins.reduce(max));
}

class _SpinCard extends StatefulWidget {
  const _SpinCard();

  @override
  State<_SpinCard> createState() => _SpinCardState();
}

class _SpinCardState extends State<_SpinCard> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(vsync: this, duration: PrismDurations.slow * 2);
  bool _spinning = false;
  bool _spun = false;
  int _won = 0;

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    setState(() => _spinning = true);
    final ProSpinResult result = await CoinsService.instance.claimProSpin();
    if (!mounted) return;
    switch (result.outcome) {
      case ProSpinOutcome.won:
        PrismHaptics.success();
        setState(() {
          _spinning = false;
          _spun = true;
          _won = result.coins;
        });
        if (context.reduceMotion) {
          _reveal.value = 1;
        } else {
          _reveal.forward(from: 0);
        }
      case ProSpinOutcome.alreadyClaimed:
        setState(() {
          _spinning = false;
          _spun = true;
        });
        _reveal.value = 1;
      case ProSpinOutcome.notPro:
        setState(() => _spinning = false);
        toasts.error('The Pro spin is for Pro members.');
      case ProSpinOutcome.failed:
        setState(() => _spinning = false);
        toasts.error("Couldn't spin. Try again.");
    }
  }

  void _showOdds() {
    final List<SpinSegment> table = CoinPolicy.proSpin;
    final double total = table.fold<double>(0, (double sum, SpinSegment s) => sum + s.weight);
    showPrismSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => PrismSheetBody(
        title: 'Pro spin odds',
        message: 'One spin a day. Every spin pays.',
        actions: <Widget>[
          PrismButton(
            label: 'Close',
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
        child: PrismGroup(
          children: <Widget>[
            for (final SpinSegment s in table)
              PrismRow(
                leading: const PrismCoinIcon(size: 24),
                title: '${s.coins} coins',
                value: '${(s.weight / total * 100).round()}%',
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = proSpinRange();
    return ValueListenableBuilder<QuestState?>(
      valueListenable: CoinsService.instance.questsNotifier,
      builder: (context, quests, _) {
        final QuestItem? bonus = quests?.bonus;
        final bool done = _spun || (bonus != null && bonus.id == 'pro_spin' && bonus.claimed);
        final TextStyle caption = PrismTextStyles.caption(context);
        return PrismCard(
          child: Row(
            children: <Widget>[
              AnimatedBuilder(
                animation: _reveal,
                builder: (context, child) => Transform.scale(
                  scale: 1 + 0.2 * sin(const Interval(0, 0.5, curve: PrismCurves.pop).transform(_reveal.value) * pi),
                  child: child,
                ),
                child: const PrismCoinIcon(size: 40),
              ),
              const SizedBox(width: PrismSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Pro spin', style: PrismTextStyles.cardTitle(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    if (done) ...<Widget>[
                      if (_won > 0)
                        AnimatedBuilder(
                          animation: _reveal,
                          builder: (context, _) {
                            final double t = const Interval(
                              0.1,
                              0.8,
                              curve: PrismCurves.enter,
                            ).transform(_reveal.value);
                            return Text('+${(_won * t).round()} coins', style: PrismTextStyles.numeral(context, 28));
                          },
                        ),
                      Text('Back tomorrow', style: caption),
                    ] else ...<Widget>[
                      Text('Once a day, ${range.low} to ${range.high} coins', style: caption),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PrismButton(
                          label: 'See the odds',
                          variant: PrismButtonVariant.ghost,
                          size: PrismButtonSize.compact,
                          onPressed: _showOdds,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!done) ...<Widget>[
                const SizedBox(width: PrismSpace.sm),
                PrismButton(label: 'Spin', size: PrismButtonSize.compact, loading: _spinning, onPressed: _spin),
              ],
            ],
          ),
        );
      },
    );
  }
}
