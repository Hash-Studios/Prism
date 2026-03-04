import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
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

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coin Transactions')),
      backgroundColor: Theme.of(context).primaryColor,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const <Widget>[
                  SizedBox(height: 140),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _items.isEmpty
            ? ListView(
                children: const <Widget>[
                  SizedBox(height: 120),
                  Center(child: Text('No coin transactions yet.')),
                ],
              )
            : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final Color amountColor = item.isCredit
                      ? Colors.green
                      : item.isDebit
                      ? Colors.red
                      : Theme.of(context).colorScheme.secondary;
                  final String amountText = item.delta > 0 ? '+${item.delta}' : '${item.delta}';
                  final bool hasLinkedFlow =
                      (item.shortLinkUrl ?? '').trim().isNotEmpty || (item.deepLinkUrl ?? '').trim().isNotEmpty;
                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: ListTile(
                      leading: Icon(
                        item.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: amountColor,
                      ),
                      title: Text(item.description),
                      subtitle: Text(
                        '${_formatTime(item.createdAt)} • Balance: ${item.balanceAfter}'
                        '${item.status == 'completed' ? '' : ' • ${item.status}'}',
                      ),
                      trailing: Text(
                        amountText,
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: amountColor, fontWeight: FontWeight.w700),
                      ),
                      onTap: hasLinkedFlow ? () => _openLinkedFlow(item) : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
