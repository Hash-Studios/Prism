import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/coins/streak_pill.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _coinAccent = Color(0xFF00BCD4);
const Color _coinGold = Color(0xFFFFC107);
const Color _coinCardSurface = Color(0xFF1A1A2E);

String _formatTime(DateTime dateTime) => DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());

@RoutePage()
class CoinTransactionsScreen extends StatefulWidget {
  const CoinTransactionsScreen({super.key});

  @override
  State<CoinTransactionsScreen> createState() => _CoinTransactionsScreenState();
}

class _CoinTransactionsScreenState extends State<CoinTransactionsScreen> {
  static const DeepLinkNavigation _deepLinkNavigation = DeepLinkNavigation();

  bool _loading = false;
  List<CoinTransactionEntry> _items = const <CoinTransactionEntry>[];
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  bool _loadingReward = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _contentLoadTracker.start();
    setState(() => _loading = true);
    try {
      final rows = await CoinsService.instance.fetchTransactions(limit: 150);
      if (!mounted) return;
      setState(() => _items = rows);
      _contentLoadTracker.success(
        itemCount: rows.length,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.coinTransactionsScreen,
              result: (itemCount ?? 0) > 0 ? EventResultValue.success : EventResultValue.empty,
              loadTimeMs: loadTimeMs,
              sourceContext: 'coin_transactions_initial_load',
              itemCount: itemCount,
            ),
          );
        },
      );
    } catch (_) {
      _contentLoadTracker.failure(
        reason: AnalyticsReasonValue.error,
        onFailure: ({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.coinTransactionsScreen,
              result: EventResultValue.failure,
              loadTimeMs: loadTimeMs,
              sourceContext: 'coin_transactions_initial_load',
              reason: reason,
            ),
          );
        },
      );
      toasts.error('Unable to load coin transactions.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openLinkedFlow(CoinTransactionEntry item) async {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.coinTransactionsScreen,
          action: AnalyticsActionValue.openTransactionLinkTapped,
          sourceContext: 'coin_transactions_item_tap',
          itemId: item.id,
        ),
      ),
    );
    final String url = (item.shortLinkUrl ?? item.deepLinkUrl ?? '').trim();
    if (url.isEmpty) {
      toasts.error('No linked item for this transaction.');
      unawaited(
        analytics.track(
          const ExternalLinkOpenResultEvent(
            surface: AnalyticsSurfaceValue.coinTransactionsScreen,
            destination: LinkDestinationValue.external,
            result: EventResultValue.failure,
            reason: AnalyticsReasonValue.missingData,
            sourceContext: 'coin_transactions_item_tap',
          ),
        ),
      );
      return;
    }
    final Uri? parsed = Uri.tryParse(url);
    if (parsed == null) {
      toasts.error('Invalid link for this transaction.');
      unawaited(
        analytics.track(
          const ExternalLinkOpenResultEvent(
            surface: AnalyticsSurfaceValue.coinTransactionsScreen,
            destination: LinkDestinationValue.external,
            result: EventResultValue.failure,
            reason: AnalyticsReasonValue.error,
            sourceContext: 'coin_transactions_item_tap',
          ),
        ),
      );
      return;
    }
    final PageRouteInfo? route = _deepLinkNavigation.isPrismDeepLink(parsed)
        ? await _deepLinkNavigation.mapUriToRoute(parsed)
        : null;
    if (route != null) {
      if (mounted) {
        context.router.navigate(route);
      }
      unawaited(
        analytics.track(
          const ExternalLinkOpenResultEvent(
            surface: AnalyticsSurfaceValue.coinTransactionsScreen,
            destination: LinkDestinationValue.external,
            result: EventResultValue.success,
            sourceContext: 'coin_transactions_item_tap.internal_route',
          ),
        ),
      );
      return;
    }
    final bool launched = await launchUrl(parsed);
    unawaited(
      analytics.track(
        ExternalLinkOpenResultEvent(
          surface: AnalyticsSurfaceValue.coinTransactionsScreen,
          destination: LinkDestinationValue.external,
          result: launched ? EventResultValue.success : EventResultValue.failure,
          reason: launched ? null : AnalyticsReasonValue.error,
          sourceContext: 'coin_transactions_item_tap',
        ),
      ),
    );
    if (!launched) {
      toasts.error('Unable to open linked wallpaper.');
    }
  }

  Future<bool> _ensureRewardedAdReady(AdsBloc bloc) async {
    if (bloc.state.ads.adLoaded) {
      return true;
    }
    if (!bloc.state.ads.loadingAd) {
      bloc.add(const AdsEvent.started());
    }
    try {
      final AdsState state = await bloc.stream
          .firstWhere((state) => state.ads.adLoaded || state.ads.adFailed)
          .timeout(const Duration(seconds: 30));
      return state.ads.adLoaded;
    } catch (_) {
      return false;
    }
  }

  Future<void> _watchRewardedAdAndCreditCoins() async {
    final AdsBloc bloc = context.read<AdsBloc>();
    if (!await _ensureRewardedAdReady(bloc)) {
      toasts.error('Ads unavailable right now. Try again later.');
      return;
    }
    bool watchRequested = false;
    try {
      final Future<AdsState> completion = bloc.stream
          .firstWhere(
            (state) => state.shouldUnlockDownload || state.actionStatus == ActionStatus.failure || state.ads.adFailed,
          )
          .timeout(const Duration(seconds: 60));
      bloc.add(const AdsEvent.watchAdRequested());
      watchRequested = true;
      final AdsState result = await completion;
      if (result.shouldUnlockDownload) {
        final credit = await CoinsService.instance.award(CoinEarnAction.rewardedAd, sourceTag: 'coins.hub.rewarded_ad');
        if (!credit.changed) {
          toasts.error('Unable to credit coins right now.');
          return;
        }
        if (mounted) {
          await PaywallOrchestrator.instance.recordRewardedAdWatchAndMaybeUpsell(source: 'coin_hub_rewarded_ad');
        }
        toasts.codeSend('+${CoinPolicy.rewardedAd} coins');
        return;
      }
      toasts.error('Ad was not completed.');
    } catch (_) {
      toasts.error('Ad was not completed.');
    } finally {
      if (watchRequested) {
        bloc.add(const AdsEvent.transientStateCleared());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            backgroundColor: Theme.of(context).primaryColor,
            surfaceTintColor: Colors.transparent,
            floating: true,
            title: _TwoToneHeading(first: 'Prism ', second: 'Coins', style: Theme.of(context).textTheme.titleLarge),
          ),
          SliverToBoxAdapter(child: _CoinHeroSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: _EarnCoinsSection(onWatchAd: _onWatchAdTapped, loadingReward: _loadingReward),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          const SliverToBoxAdapter(child: _HowCoinsUsedSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: _TransactionsSection(loading: _loading, items: _items, onRefresh: _load, onTapItem: _openLinkedFlow),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Future<void> _onWatchAdTapped() async {
    if (_loadingReward) return;
    setState(() => _loadingReward = true);
    await _watchRewardedAdAndCreditCoins();
    if (mounted) {
      setState(() => _loadingReward = false);
    }
  }
}

class _CoinHeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        decoration: BoxDecoration(
          color: _coinCardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _coinAccent.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          children: <Widget>[
            const PrismCoinIcon(size: 100),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: CoinsService.instance.balanceNotifier,
              builder: (context, balance, _) {
                return Column(
                  children: <Widget>[
                    Text(
                      '$balance',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 40),
                    ),
                    const Text(
                      'coins',
                      style: TextStyle(color: _coinGold, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1.2),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const StreakPill(compact: true),
          ],
        ),
      ),
    );
  }
}

class _EarnCoinsSection extends StatelessWidget {
  const _EarnCoinsSection({required this.onWatchAd, required this.loadingReward});

  final VoidCallback onWatchAd;
  final bool loadingReward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TwoToneHeading(first: 'Earn', second: ' Coins', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _WatchAdItem(onTap: onWatchAd, loading: loadingReward),
          const SizedBox(height: 8),
          const _CoinRow(
            icon: Icons.local_fire_department_rounded,
            label: 'Daily Streak (Day 1–2)',
            value: '+${CoinPolicy.streakDay1To2Daily}c/day',
            accentColor: Colors.orange,
            valueColor: Colors.green,
          ),
          const SizedBox(height: 8),
          _CoinRow(
            icon: Icons.local_fire_department_rounded,
            label: 'Daily Streak (Day 7)',
            value: '+${CoinPolicy.streakTotalRewardForDay(7)}c',
            accentColor: Colors.orange,
            valueColor: Colors.green,
          ),
          const SizedBox(height: 8),
          const _CoinRow(
            icon: Icons.people_outline,
            label: 'Refer Friend',
            value: '+${CoinPolicy.referral}c',
            accentColor: Color(0xFF9C27B0),
            valueColor: Colors.green,
          ),
          const SizedBox(height: 8),
          const _CoinRow(
            icon: Icons.upload_outlined,
            label: 'First Upload',
            value: '+${CoinPolicy.firstWallpaperUpload}c',
            accentColor: Colors.green,
            valueColor: Colors.green,
          ),
          const SizedBox(height: 8),
          const _CoinRow(
            icon: Icons.person_outline,
            label: 'Profile Completion',
            value: '+${CoinPolicy.profileCompletion}c',
            accentColor: Colors.blue,
            valueColor: Colors.green,
          ),
        ],
      ),
    );
  }
}

class _WatchAdItem extends StatelessWidget {
  const _WatchAdItem({required this.onTap, required this.loading});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const Color accent = _coinAccent;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).hintColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_outline, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Watch Ad', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              if (loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '+${CoinPolicy.rewardedAd}c',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowCoinsUsedSection extends StatelessWidget {
  const _HowCoinsUsedSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TwoToneHeading(first: 'How Coins', second: ' Are Used', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _CoinRow(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Generation (Fast)',
            value: '${CoinPolicy.aiGenerationFast}c',
            accentColor: Theme.of(context).colorScheme.primary,
            valueColor: Colors.red,
          ),
          const SizedBox(height: 8),
          _CoinRow(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Generation (Balanced)',
            value: '${CoinPolicy.aiGenerationBalanced}c',
            accentColor: Theme.of(context).colorScheme.primary,
            valueColor: Colors.red,
          ),
          const SizedBox(height: 8),
          _CoinRow(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Generation (Quality)',
            value: '${CoinPolicy.aiGenerationQuality}c',
            accentColor: Theme.of(context).colorScheme.primary,
            valueColor: Colors.red,
          ),
          const SizedBox(height: 8),
          const _CoinRow(
            icon: Icons.download_outlined,
            label: 'Download Wallpaper',
            value: '${CoinPolicy.wallpaperDownload}c',
            accentColor: _coinAccent,
            valueColor: Colors.red,
          ),
          const SizedBox(height: 8),
          const _CoinRow(
            icon: Icons.download_outlined,
            label: 'Premium Wallpaper',
            value: '${CoinPolicy.premiumWallpaperDownload}c',
            accentColor: Colors.amber,
            valueColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _CoinRow extends StatelessWidget {
  const _CoinRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: valueColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoToneHeading extends StatelessWidget {
  const _TwoToneHeading({required this.first, required this.second, required this.style});

  final String first;
  final String second;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: first,
            style: style?.copyWith(color: _coinAccent, fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: second,
            style: style?.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({
    required this.loading,
    required this.items,
    required this.onRefresh,
    required this.onTapItem,
  });

  final bool loading;
  final List<CoinTransactionEntry> items;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CoinTransactionEntry) onTapItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TwoToneHeading(first: 'Recent', second: ' Activity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text('No coin transactions yet.', style: Theme.of(context).textTheme.bodyMedium)),
            )
          else
            Column(
              children: <Widget>[
                for (final item in items) ...<Widget>[
                  _TransactionTile(item: item, onTap: () => onTapItem(item)),
                  const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.onTap});

  final CoinTransactionEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color amountColor = item.isCredit
        ? Colors.green
        : item.isDebit
        ? Colors.red
        : Theme.of(context).colorScheme.secondary;
    final String amountText = item.delta > 0 ? '+${item.delta}' : '${item.delta}';
    final bool hasLinkedFlow =
        (item.shortLinkUrl ?? '').trim().isNotEmpty || (item.deepLinkUrl ?? '').trim().isNotEmpty;

    return GestureDetector(
      onTap: hasLinkedFlow ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).hintColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: amountColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: amountColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(
                item.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: amountColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(item.createdAt)}  ·  Balance: ${item.balanceAfter}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: amountColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                amountText,
                style: TextStyle(color: amountColor, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
