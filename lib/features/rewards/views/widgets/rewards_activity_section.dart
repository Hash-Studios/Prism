import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/coin_transaction_label.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_bits.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/core/widgets/prism/prism_section.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int _kActivityLimit = 30;
const int _kActivityCollapsed = 8;

/// "Activity": the latest coin transactions. "See all" opens the full coin history.
class RewardsActivitySection extends StatefulWidget {
  const RewardsActivitySection({super.key, this.onSeeAll});

  /// Test hook. By default it pushes [CoinHistoryRoute].
  final VoidCallback? onSeeAll;

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
      setState(() => _items = rows.where((CoinTransactionEntry e) => e.delta != 0).toList(growable: false));
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

  void _seeAll() {
    PrismHaptics.tap();
    _openHistory();
  }

  void _openHistory() {
    final VoidCallback? override = widget.onSeeAll;
    if (override != null) {
      override();
      return;
    }
    context.router.root.push(const CoinHistoryRoute());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Widget body;
    if (_loading) {
      body = const _ActivitySkeleton();
    } else if (_failed) {
      body = PrismInlineState(
        icon: Icons.cloud_off_rounded,
        title: l10n.economyActivityLoadFailed,
        body: l10n.errorNetwork,
        actionLabel: l10n.actionRetry,
        onAction: _load,
      );
    } else if (_items.isEmpty) {
      body = PrismInlineState(
        icon: Icons.receipt_long_rounded,
        title: l10n.economyCoinHistoryEmpty,
        body: l10n.economyActivityEmptyMessage,
      );
    } else {
      final int shown = _items.length.clamp(0, _kActivityCollapsed);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PrismGroup(children: <Widget>[for (int i = 0; i < shown; i++) _ActivityRow(entry: _items[i])]),
          if (_items.length > _kActivityCollapsed)
            Center(
              child: PrismButton(
                label: l10n.economyShowMore,
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: _openHistory,
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(
          title: l10n.economyActivity,
          padding: const EdgeInsets.only(top: PrismSpace.xxl, bottom: PrismSpace.sm),
          actionLabel: !_loading && !_failed && _items.isNotEmpty ? l10n.economySeeAll : null,
          onAction: _seeAll,
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
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String formattedDelta = formatLocalizedNumber(entry.delta.abs(), l10n);
    final String amount = entry.delta > 0 ? '+$formattedDelta' : '-$formattedDelta';
    final String label = coinTransactionLabel(entry, l10n);
    final String date = _relativeDate(l10n, entry.createdAt, locale: Localizations.localeOf(context).toLanguageTag());
    return Semantics(
      container: true,
      label: l10n.economyCoinActivitySemantics(label, date, amount, entry.delta.abs()),
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

String _relativeDate(AppLocalizations l10n, DateTime when, {required String locale, DateTime? now}) {
  final DateTime local = when.toLocal();
  final DateTime today = now ?? DateTime.now();
  final int days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days <= 0) return l10n.economyToday;
  if (days == 1) return l10n.economyYesterday;
  if (days < 7) return l10n.economyDaysAgo(days);
  return DateFormat.yMMMd(locale).format(local);
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
