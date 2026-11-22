import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/coin_packs/data/coin_pack_gateway.dart';
import 'package:Prism/features/coin_packs/domain/coin_pack.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The "Get coins" sheet. It shows the coin packs and starts a purchase through [gateway]. The server grants
/// the coins. This sheet only shows the result.
class CoinPacksSheet extends StatefulWidget {
  const CoinPacksSheet({super.key, required this.source, required this.gateway, this.message});

  final String source;
  final String? message;
  final CoinPackGateway gateway;

  @override
  State<CoinPacksSheet> createState() => _CoinPacksSheetState();
}

sealed class _Phase {
  const _Phase();
}

final class _Loading extends _Phase {
  const _Loading();
}

final class _LoadFailed extends _Phase {
  const _LoadFailed();
}

final class _Ready extends _Phase {
  const _Ready(this.packs, {this.failed = false});

  final List<CoinPack> packs;
  final bool failed;
}

final class _Purchasing extends _Phase {
  const _Purchasing(this.packs, this.productId, {this.verifying = false});

  final List<CoinPack> packs;
  final String productId;
  final bool verifying;
}

final class _Granted extends _Phase {
  const _Granted(this.result);

  final CoinPackGranted result;
}

final class _Pending extends _Phase {
  const _Pending();
}

CoinPackOutcomeValue _outcomeOf(CoinPackPurchaseResult result) => switch (result) {
  CoinPackGranted() => CoinPackOutcomeValue.granted,
  CoinPackPending() => CoinPackOutcomeValue.pending,
  CoinPackCancelled() => CoinPackOutcomeValue.cancelled,
  CoinPackFailed() => CoinPackOutcomeValue.failed,
};

class _CoinPacksSheetState extends State<CoinPacksSheet> {
  _Phase _phase = const _Loading();
  bool _viewTracked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<CoinPack> packs = await widget.gateway.loadPacks();
      if (!mounted) return;
      _trackViewed(packs.length);
      setState(() => _phase = _Ready(packs));
    } catch (_) {
      if (!mounted) return;
      _trackViewed(0);
      setState(() => _phase = const _LoadFailed());
    }
  }

  void _retry() {
    setState(() => _phase = const _Loading());
    _load();
  }

  void _trackViewed(int packCount) {
    if (_viewTracked) return;
    _viewTracked = true;
    analytics.track(CoinPackViewedEvent(source: widget.source, packCount: packCount));
  }

  Future<void> _buy(CoinPack pack) async {
    final _Phase phase = _phase;
    if (phase is! _Ready) return;
    final List<CoinPack> packs = phase.packs;
    setState(() => _phase = _Purchasing(packs, pack.productId));
    analytics.track(CoinPackPurchaseStartedEvent(pack: pack.productId, source: widget.source));
    final CoinPackPurchaseResult result = await widget.gateway.buy(
      pack,
      onVerifying: () {
        if (!mounted) return;
        final _Phase current = _phase;
        if (current is! _Purchasing) return;
        setState(() => _phase = _Purchasing(current.packs, current.productId, verifying: true));
      },
    );
    if (!mounted) return;
    analytics.track(CoinPackPurchasedEvent(pack: pack.productId, outcome: _outcomeOf(result), source: widget.source));
    setState(() {
      _phase = switch (result) {
        final CoinPackGranted granted => _Granted(granted),
        CoinPackPending() => const _Pending(),
        CoinPackCancelled() => _Ready(packs),
        CoinPackFailed() => _Ready(packs, failed: true),
      };
    });
    if (result is CoinPackGranted) PrismHaptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String intro = widget.message ?? l10n.coinPacksSubtitle;

    return switch (_phase) {
      _Loading() => _body(
        context,
        message: intro,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: PrismSpace.sm),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      _LoadFailed() => _body(
        context,
        message: intro,
        child: Text(l10n.coinPacksLoadFailed, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
        actions: <Widget>[PrismButton(label: l10n.coinPacksRetry, expand: true, onPressed: _retry)],
      ),
      _Ready(:final List<CoinPack> packs, :final bool failed) => _body(
        context,
        message: intro,
        child: _packView(
          context,
          packs: packs,
          failedText: failed
              ? Text(
                  l10n.coinPacksFailed,
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.caption(context).copyWith(color: scheme.error),
                )
              : null,
        ),
        actions: <Widget>[
          PrismButton(
            label: l10n.coinPacksEarnInRewards,
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: () {
              final StackRouter router = context.router;
              Navigator.of(context).pop();
              router.pushPath('/rewards');
            },
          ),
        ],
      ),
      _Purchasing(:final List<CoinPack> packs, :final String productId, :final bool verifying) => _body(
        context,
        message: intro,
        child: _packView(
          context,
          packs: packs,
          purchasingId: productId,
          statusText: Text(
            verifying ? l10n.coinPacksVerifying : l10n.coinPacksPurchasing,
            textAlign: TextAlign.center,
            style: PrismTextStyles.caption(context),
          ),
        ),
      ),
      _Granted(:final CoinPackGranted result) => _body(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const PrismCoinIcon(size: 56),
            const SizedBox(height: PrismSpace.sm),
            Text(
              l10n.coinPacksSuccess(result.coins, result.balance),
              textAlign: TextAlign.center,
              style: PrismTextStyles.body(context),
            ),
          ],
        ),
        actions: <Widget>[_doneButton(context)],
      ),
      _Pending() => _body(
        context,
        child: Text(l10n.coinPacksPending, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
        actions: <Widget>[_doneButton(context)],
      ),
    };
  }

  Widget _body(
    BuildContext context, {
    required Widget child,
    String? message,
    List<Widget> actions = const <Widget>[],
  }) {
    return PrismSheetBody(
      title: context.l10n.coinPacksTitle,
      message: message,
      centered: true,
      actions: actions,
      child: child,
    );
  }

  Widget _packView(
    BuildContext context, {
    required List<CoinPack> packs,
    String? purchasingId,
    Widget? statusText,
    Widget? failedText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (packs.isEmpty)
          Text(context.l10n.coinPacksEmpty, textAlign: TextAlign.center, style: PrismTextStyles.body(context))
        else
          for (final CoinPack pack in packs)
            Padding(
              padding: const EdgeInsets.only(bottom: PrismSpace.xs),
              child: _PackRow(
                pack: pack,
                busy: pack.productId == purchasingId,
                enabled: purchasingId == null,
                onTap: purchasingId == null ? () => _buy(pack) : null,
              ),
            ),
        if (statusText != null)
          Padding(
            padding: const EdgeInsets.only(top: PrismSpace.sm),
            child: statusText,
          ),
        if (failedText != null)
          Padding(
            padding: const EdgeInsets.only(top: PrismSpace.sm),
            child: failedText,
          ),
      ],
    );
  }

  Widget _doneButton(BuildContext context) {
    return PrismButton(label: context.l10n.coinPacksDone, expand: true, onPressed: () => Navigator.of(context).pop());
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack, required this.busy, required this.enabled, required this.onTap});

  final CoinPack pack;
  final bool busy;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey<String>('coin-pack-${pack.productId}'),
      button: true,
      enabled: enabled,
      label: l10n.coinPacksBuyLabel(pack.coins, pack.priceString),
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.sm),
            child: Row(
              children: <Widget>[
                const PrismCoinIcon(size: 24),
                const SizedBox(width: PrismSpace.sm),
                Expanded(
                  child: Wrap(
                    spacing: PrismSpace.xs,
                    runSpacing: PrismSpace.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(l10n.coinPacksCoins(pack.coins), style: PrismTextStyles.rowTitle(context)),
                      if (pack.bonusPercent > 0)
                        Text(
                          l10n.coinPacksBonus(pack.bonusPercent),
                          style: PrismTextStyles.caption(context).copyWith(color: scheme.primary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: PrismSpace.sm),
                if (busy)
                  const SizedBox.square(dimension: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                else
                  Flexible(
                    child: Text(pack.priceString, textAlign: TextAlign.end, style: PrismTextStyles.rowTitle(context)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
