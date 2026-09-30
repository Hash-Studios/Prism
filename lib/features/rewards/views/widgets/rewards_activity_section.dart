import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int _kActivityLimit = 30;

/// "Activity": the latest coin transactions.
class RewardsActivitySection extends StatefulWidget {
  const RewardsActivitySection({super.key});

  @override
  State<RewardsActivitySection> createState() => _RewardsActivitySectionState();
}

class _RewardsActivitySectionState extends State<RewardsActivitySection> {
  bool _loading = true;
  bool _failed = false;
  bool _inFlight = false;
  bool _reloadRequested = false;
  List<CoinTransactionEntry> _items = const <CoinTransactionEntry>[];

  @override
  void initState() {
    super.initState();
    CoinsService.instance.balanceNotifier.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    CoinsService.instance.balanceNotifier.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (_inFlight) {
      _reloadRequested = true;
      return;
    }
    _inFlight = true;
    final user = app_state.prismUser;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final List<CoinTransactionEntry> rows = await CoinsService.instance.fetchTransactions(
        limit: _kActivityLimit,
        fresh: true,
      );
      if (!mounted || !identical(user, app_state.prismUser)) return;
      setState(() => _items = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      _inFlight = false;
      if (mounted) setState(() => _loading = false);
      if (mounted && _reloadRequested) {
        _reloadRequested = false;
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Widget body;
    if (_loading) {
      body = const _ActivitySkeleton();
    } else if (_failed) {
      body = Row(
        children: <Widget>[
          Expanded(child: Text("Couldn't load activity.", style: theme.textTheme.bodyMedium)),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    } else if (_items.isEmpty) {
      body = Text(
        'No coin activity yet.',
        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.6)),
      );
    } else {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < _items.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant.withValues(alpha: 0.4)),
              _ActivityRow(entry: _items[i]),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Activity', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final CoinTransactionEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color amountColor = entry.isCredit ? scheme.tertiary : scheme.onSurface.withValues(alpha: 0.6);
    final String amount = entry.delta > 0 ? '+${entry.delta}' : '${entry.delta}';
    final String label = coinTransactionLabel(entry);
    final String date = _relativeDate(entry.createdAt);
    return Semantics(
      container: true,
      label: '$label, $date, $amount coins',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              amount,
              style: theme.textTheme.titleSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeDate(DateTime when, {DateTime? now}) {
  final DateTime local = when.toLocal();
  final DateTime today = now ?? DateTime.now();
  final int days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return DateFormat(local.year == today.year ? 'd MMM' : 'd MMM y').format(local);
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return PulsePlaceholder(
      builder: (context, _) => Column(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            const SizedBox(
              height: 52,
              width: double.infinity,
              child: PulseFill(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ],
        ],
      ),
    );
  }
}
