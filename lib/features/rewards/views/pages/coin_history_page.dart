import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/rewards/data/coin_history_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _HistoryFilter { earned, spent, refunds }

extension on _HistoryFilter {
  String label(AppLocalizations l10n) => switch (this) {
    _HistoryFilter.earned => l10n.economyCoinHistoryEarned,
    _HistoryFilter.spent => l10n.economyCoinHistorySpent,
    _HistoryFilter.refunds => l10n.economyCoinHistoryRefunds,
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
  /// Pages one pull may read while every row it got is hidden or filtered out.
  static const int _maxPagesPerPull = 5;

  final CoinHistoryRepository _repository = CoinHistoryRepository();
  final List<CoinTransactionEntry> _items = <CoinTransactionEntry>[];
  final Map<String?, Future<CoinHistoryBatch>> _pendingPages = <String?, Future<CoinHistoryBatch>>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;
  bool _hasMore = false;
  String? _cursor;
  _HistoryFilter? _filter;
  int _generation = 0;
  String? _owner;
  bool _refreshPending = false;
  StreamSubscription<PrismUsersV2>? _sessionSubscription;

  String? get _currentOwner => app_state.prismUser.loggedIn ? app_state.prismUser.id : null;

  @override
  void initState() {
    super.initState();
    analytics.track(const CoinHistoryOpenedEvent());
    _owner = _currentOwner;
    CoinsService.instance.balanceNotifier.addListener(_refresh);
    if (getIt.isRegistered<SessionRepository>()) {
      _sessionSubscription = getIt<SessionRepository>().watchCurrentUser().listen((_) {
        if (_owner != _currentOwner) _refresh();
      });
    }
    _refresh();
  }

  @override
  void dispose() {
    CoinsService.instance.balanceNotifier.removeListener(_refresh);
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  void _refresh() {
    final bool changedOwner = _owner != _currentOwner;
    _owner = _currentOwner;
    _generation++;
    _cursor = null;
    _hasMore = false;
    _refreshPending = true;
    if (changedOwner) _items.clear();
    if (_owner == null || _owner!.isEmpty) {
      setState(() {
        _items.clear();
        _loading = false;
        _loadingMore = false;
        _failed = false;
      });
      return;
    }
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh && (_loading || _loadingMore)) return;
    final int generation = ++_generation;
    final String? owner = _owner;
    bool isCurrent() => mounted && generation == _generation && owner == _currentOwner;
    final bool first = _refreshPending || _cursor == null;
    setState(() {
      _failed = false;
      _loadingMore = false;
      if (first) {
        _loading = _items.isEmpty;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final Future<CoinHistoryBatch>? pending = _pendingPages[owner];
      if (pending != null) {
        try {
          await pending;
        } catch (_) {
          if (!isCurrent()) return;
        }
        if (!isCurrent()) return;
      }
      final List<CoinTransactionEntry> fetched = <CoinTransactionEntry>[];
      String? cursor = first ? null : _cursor;
      CoinHistoryBatch batch;
      int pages = 0;
      do {
        final Future<CoinHistoryBatch> request = _repository.fetchPage(startAfterDocId: cursor);
        _pendingPages[owner] = request;
        try {
          batch = await request;
        } finally {
          if (identical(_pendingPages[owner], request)) _pendingPages.remove(owner);
        }
        if (!isCurrent()) return;
        fetched.addAll(batch.items);
        cursor = batch.cursor ?? cursor;
        pages++;
      } while (batch.hasMore && pages < _maxPagesPerPull && _visible(fetched).isEmpty);
      if (!isCurrent()) return;
      setState(() {
        if (first) _items.clear();
        _items.addAll(fetched);
        _refreshPending = false;
        _hasMore = batch.hasMore;
        _cursor = cursor;
      });
    } catch (_) {
      if (!isCurrent()) return;
      setState(() => _failed = true);
    } finally {
      if (isCurrent()) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<CoinTransactionEntry> _visible(List<CoinTransactionEntry> rows) {
    final _HistoryFilter? filter = _filter;
    return filter == null ? rows : rows.where(filter.matches).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _HistoryFilter? filter = _filter;
    final List<CoinTransactionEntry> shown = _visible(_items);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Semantics(
          header: true,
          child: Text(l10n.economyCoinHistoryTitle, style: PrismTextStyles.screenTitle(context)),
        ),
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
                        label: Text(option.label(l10n)),
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
                child: _Message(text: l10n.economyCoinHistoryLoadFailed, onRetry: _load),
              )
            else if (_items.isEmpty && !_hasMore)
              SliverToBoxAdapter(child: _Message(text: l10n.economyCoinHistoryEmpty))
            else ...<Widget>[
              if (shown.isEmpty)
                SliverToBoxAdapter(
                  child: _Message(
                    text: _hasMore ? l10n.economyCoinHistoryNoLoadedRows : l10n.economyCoinHistoryNothingHere,
                  ),
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
                        ? TextButton(onPressed: _load, child: Text(l10n.economyAiTryAgain))
                        : _loadingMore
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : _hasMore
                        ? TextButton(
                            onPressed: () {
                              PrismHaptics.tap();
                              _load();
                            },
                            child: Text(l10n.economyShowMore, style: PrismTextStyles.rowTitle(context)),
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
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(text, style: PrismTextStyles.body(context))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: Text(l10n.economyAiTryAgain)),
        ],
      ),
    );
  }
}

String _historyDescription(CoinTransactionEntry entry) {
  final String description = entry.description.trim();
  final bool isInternalReason = switch (entry.action) {
    'aiGeneration' => description == 'ai_generation_reserved' || description == 'ai_generation',
    'premiumPreview24h' => description == 'premium_preview_unlock_24h',
    'wallpaperDownload' || 'premiumWallpaperDownload' =>
      description == entry.action || RegExp(r'^content_[A-Za-z0-9_-]+$').hasMatch(description),
    _ => false,
  };
  return isInternalReason ? '' : description;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final CoinTransactionEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color amountColor = entry.isCredit ? scheme.tertiary : scheme.onSurface.withValues(alpha: 0.6);
    final String formattedDelta = formatLocalizedNumber(entry.delta.abs(), l10n);
    final String amount = entry.delta > 0 ? '+$formattedDelta' : '-$formattedDelta';
    final String label = coinTransactionLabel(entry, l10n);
    final String date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_jm().format(entry.createdAt.toLocal());
    final String description = _historyDescription(entry);
    final bool showDescription = description.isNotEmpty && description.toLowerCase() != label.toLowerCase();
    final String balance = l10n.economyCoinBalance(entry.balanceAfter);
    return Semantics(
      container: true,
      label: l10n.economyCoinHistoryRowSemantics(
        label,
        showDescription.toString(),
        description,
        date,
        amount,
        entry.delta.abs(),
        balance,
      ),
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
