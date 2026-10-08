import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/rewards/data/coin_history_repository.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _HistoryFilter { earned, spent, refunds }

extension on _HistoryFilter {
  String get label => switch (this) {
    _HistoryFilter.earned => 'Earned',
    _HistoryFilter.spent => 'Spent',
    _HistoryFilter.refunds => 'Refunds',
  };

  bool matches(CoinTransactionEntry e) => switch (this) {
    _HistoryFilter.earned => e.delta > 0 && e.action != 'refund',
    _HistoryFilter.spent => e.delta < 0,
    _HistoryFilter.refunds => e.action == 'refund',
  };
}

/// Every coin transaction, newest first. Filters work on the pages already loaded.
@RoutePage()
class CoinHistoryPage extends StatefulWidget {
  const CoinHistoryPage({super.key});

  @override
  State<CoinHistoryPage> createState() => _CoinHistoryPageState();
}

class _CoinHistoryPageState extends State<CoinHistoryPage> {
  final CoinHistoryRepository _repository = CoinHistoryRepository();
  final List<CoinTransactionEntry> _items = <CoinTransactionEntry>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;
  bool _hasMore = false;
  _HistoryFilter? _filter;

  @override
  void initState() {
    super.initState();
    analytics.track(const CoinHistoryOpenedEvent());
    _load();
  }

  Future<void> _load() async {
    final bool first = _items.isEmpty;
    setState(() {
      _failed = false;
      if (first) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final CoinHistoryBatch batch = await _repository.fetchPage(startAfterDocId: first ? null : _items.last.id);
      if (!mounted) return;
      setState(() {
        _items.addAll(batch.items);
        _hasMore = batch.hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _HistoryFilter? filter = _filter;
    final List<CoinTransactionEntry> shown = filter == null
        ? _items
        : _items.where(filter.matches).toList(growable: false);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Semantics(header: true, child: Text('Coin history', style: PrismTextStyles.screenTitle(context))),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final _HistoryFilter option in _HistoryFilter.values)
                      FilterChip(
                        label: Text(option.label),
                        selected: filter == option,
                        onSelected: (selected) {
                          PrismHaptics.selection();
                          setState(() => _filter = selected ? option : null);
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _HistorySkeleton()),
              )
            else if (_failed && _items.isEmpty)
              SliverToBoxAdapter(
                child: _Message(text: "Couldn't load your coin history.", onRetry: _load),
              )
            else if (_items.isEmpty)
              const SliverToBoxAdapter(child: _Message(text: 'No coin activity yet.'))
            else ...<Widget>[
              if (shown.isEmpty)
                SliverToBoxAdapter(
                  child: _Message(text: _hasMore ? 'Nothing here in the rows loaded so far.' : 'Nothing here yet.'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: shown.length,
                    separatorBuilder: (context, _) =>
                        Divider(height: 1, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.08)),
                    itemBuilder: (context, index) => _HistoryRow(entry: shown[index]),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _failed
                        ? TextButton(onPressed: _load, child: const Text('Try again'))
                        : _loadingMore
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : _hasMore
                        ? TextButton(
                            onPressed: () {
                              PrismHaptics.tap();
                              _load();
                            },
                            child: Text('Show more', style: PrismTextStyles.rowTitle(context)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(text, style: PrismTextStyles.body(context))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final CoinTransactionEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color amountColor = entry.isCredit ? scheme.tertiary : scheme.onSurface.withValues(alpha: 0.6);
    final String amount = entry.delta > 0 ? '+${entry.delta}' : '${entry.delta}';
    final String label = coinTransactionLabel(entry);
    final String date = DateFormat('d MMM y, h:mm a').format(entry.createdAt.toLocal());
    final String description = entry.description.trim();
    final bool showDescription = description.isNotEmpty && description.toLowerCase() != label.toLowerCase();
    final String balance = 'Balance ${entry.balanceAfter}';
    return Semantics(
      container: true,
      label: '$label, ${showDescription ? '$description, ' : ''}$date, $amount coins, $balance',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
                  if (showDescription) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.body(context),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(date, style: PrismTextStyles.caption(context)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  amount,
                  style: PrismTextStyles.rowTitle(context).copyWith(color: amountColor, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(balance, style: PrismTextStyles.caption(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return PulsePlaceholder(
      builder: (context, _) => Column(
        children: <Widget>[
          for (int i = 0; i < 5; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            const SizedBox(
              height: 56,
              width: double.infinity,
              child: PulseFill(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ],
        ],
      ),
    );
  }
}
