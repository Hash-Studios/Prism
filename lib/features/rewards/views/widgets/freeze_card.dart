import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Opens the streak freeze buy flow. [onEarnCoins] runs when the user has too few coins and asks how to get more.
Future<void> buyStreakFreezeFlow(BuildContext context, {required VoidCallback onEarnCoins}) async {
  if (CoinsService.instance.streakNotifier.value.freezes >= CoinPolicy.maxStreakFreezes) {
    toasts.error('You already hold ${CoinPolicy.maxStreakFreezes} freezes.');
    return;
  }
  final _FreezeSheetResult? result = await showPrismSheet<_FreezeSheetResult>(
    context: context,
    useSafeArea: true,
    builder: (_) => const _FreezeSheet(),
  );
  if (result == null || !context.mounted) return;
  switch (result) {
    case _FreezeSheetResult.bought:
      showGlintToast(context);
      toasts.success('Streak freeze added.');
    case _FreezeSheetResult.earn:
      onEarnCoins();
  }
}

enum _FreezeSheetResult { bought, earn }

/// How many streak freezes you hold, and the way to buy one.
class FreezeCard extends StatelessWidget {
  const FreezeCard({super.key, required this.onEarnCoins});

  /// Scrolls to the earn section.
  final VoidCallback onEarnCoins;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int held = status.freezes.clamp(0, CoinPolicy.maxStreakFreezes);
        final bool full = held >= CoinPolicy.maxStreakFreezes;
        return PrismCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Streak freeze', style: PrismTextStyles.cardTitle(context)),
                  Text(
                    '$held of ${CoinPolicy.maxStreakFreezes}',
                    style: PrismTextStyles.caption(context).copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: PrismSpace.xxs),
              Text('Saves your streak if you miss a day. It applies on its own.', style: PrismTextStyles.body(context)),
              const SizedBox(height: PrismSpace.sm),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: PrismSpace.xs,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0; i < CoinPolicy.maxStreakFreezes; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: PrismSpace.xs),
                          _Slot(filled: i < held),
                        ],
                      ],
                    ),
                    PrismButton(
                      label: full ? 'Full' : 'Get one · ${CoinPolicy.streakFreezeCost}',
                      trailing: full ? null : const PrismCoinIcon(size: 16),
                      variant: PrismButtonVariant.tonal,
                      size: PrismButtonSize.compact,
                      onPressed: full ? null : () => buyStreakFreezeFlow(context, onEarnCoins: onEarnCoins),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: filled ? 'Freeze held' : 'Empty freeze slot',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: context.motion(PrismDurations.fast),
        curve: PrismCurves.enter,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PrismRadius.sm),
          color: filled ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: filled ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant, width: 1.5),
        ),
        child: Icon(Icons.ac_unit_rounded, size: 22, color: filled ? cs.primary : cs.onSurfaceVariant),
      ),
    );
  }
}

class _FreezeSheet extends StatefulWidget {
  const _FreezeSheet();

  @override
  State<_FreezeSheet> createState() => _FreezeSheetState();
}

class _FreezeSheetState extends State<_FreezeSheet> {
  bool _busy = false;
  bool _short = CoinsService.instance.balanceNotifier.value < CoinPolicy.streakFreezeCost;

  @override
  void initState() {
    super.initState();
    CoinsService.instance.balanceNotifier.addListener(_balanceChanged);
  }

  void _balanceChanged() {
    setState(() {
      if (!_busy) _short = CoinsService.instance.balanceNotifier.value < CoinPolicy.streakFreezeCost;
    });
  }

  @override
  void dispose() {
    CoinsService.instance.balanceNotifier.removeListener(_balanceChanged);
    super.dispose();
  }

  Future<void> _buy() async {
    setState(() => _busy = true);
    final StreakFreezePurchase purchase = await CoinsService.instance.buyStreakFreeze();
    if (!mounted) return;
    switch (purchase.outcome) {
      case StreakFreezeOutcome.success:
        Navigator.of(context).pop(_FreezeSheetResult.bought);
        return;
      case StreakFreezeOutcome.insufficientBalance:
        setState(() {
          _busy = false;
          _short = true;
        });
        return;
      case StreakFreezeOutcome.atCap:
        toasts.error('You already hold ${CoinPolicy.maxStreakFreezes} freezes.');
      case StreakFreezeOutcome.unavailable:
        toasts.error('Streak freeze is not available right now. Try again later.');
      case StreakFreezeOutcome.failed:
        toasts.error('Could not buy a freeze. Try again.');
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final int balance = CoinsService.instance.balanceNotifier.value;
    const int cost = CoinPolicy.streakFreezeCost;
    return PopScope(
      canPop: !_busy,
      child: _short
          ? PrismSheetBody(
              mood: GlintMood.worried,
              centered: true,
              title: 'You need $cost coins.',
              message: 'You have $balance.',
              actions: <Widget>[
                PrismButton(
                  label: 'Earn coins',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(_FreezeSheetResult.earn),
                ),
              ],
            )
          : PrismSheetBody(
              title: 'Buy a streak freeze for $cost coins?',
              message: 'Balance after: ${balance - cost}',
              actions: <Widget>[
                PrismButton(label: 'Buy', expand: true, loading: _busy, onPressed: _busy ? null : _buy),
                PrismButton(
                  label: 'Cancel',
                  expand: true,
                  variant: PrismButtonVariant.ghost,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
    );
  }
}
