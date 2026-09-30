import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int _kActivityLimit = 30;
const int _kActivityCollapsed = 8;

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
  bool _expanded = false;
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
    // Keep the rows on screen while a refresh runs: only a first load shows the skeleton.
    setState(() {
      _loading = _items.isEmpty;
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
    final Widget body;
    if (_loading) {
      body = const _ActivitySkeleton();
    } else if (_failed) {
      body = PrismInlineState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load activity.",
        body: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: _load,
      );
    } else if (_items.isEmpty) {
      body = const PrismInlineState(
        icon: Icons.receipt_long_rounded,
        title: 'No coin activity yet.',
        body: 'Watch a video or keep your streak to earn your first coins.',
      );
    } else {
      final int shown = _expanded ? _items.length : _items.length.clamp(0, _kActivityCollapsed);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PrismGroup(children: <Widget>[for (int i = 0; i < shown; i++) _ActivityRow(entry: _items[i])]),
          if (_items.length > _kActivityCollapsed)
            Center(
              child: PrismButton(
                label: _expanded ? 'Show less' : 'Show more',
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PrismSectionHeader(
          title: 'Activity',
          padding: EdgeInsets.only(top: PrismSpace.xxl, bottom: PrismSpace.sm),
        ),
        body,
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final CoinTransactionEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String amount = entry.delta > 0 ? '+${entry.delta}' : '${entry.delta}';
    final String label = coinTransactionLabel(entry);
    final String date = _relativeDate(entry.createdAt);
    return Semantics(
      container: true,
      label: '$label, $date, $amount coins',
      excludeSemantics: true,
      child: PrismRow(
        icon: entry.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        title: label,
        subtitle: date,
        trailing: Text(
          amount,
          style: PrismTextStyles.rowTitle(
            context,
          ).copyWith(color: entry.isCredit ? scheme.tertiary : scheme.onSurface, fontWeight: FontWeight.w700),
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
    return PrismSkeleton(
      child: PrismCard(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.xs),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
                child: Row(
                  children: <Widget>[
                    const PrismBone(width: 32, height: 32, radius: PrismRadius.xs + 2),
                    const SizedBox(width: PrismSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          PrismBone(width: 120.0 + (i % 2) * 40),
                          const SizedBox(height: PrismSpace.xs),
                          const PrismBone(width: 70, height: 11),
                        ],
                      ),
                    ),
                    const PrismBone(width: 32),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
