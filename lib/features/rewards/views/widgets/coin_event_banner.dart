import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_events.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "Sun 23:59" when [local] is within six days of [localNow], else "Nov 20 23:59".
String formatCoinEventTime(DateTime local, DateTime localNow, String locale, {required bool use24h}) {
  final bool nearby = local.difference(localNow) < const Duration(days: 6);
  final DateFormat day = nearby ? DateFormat.E(locale) : DateFormat.MMMd(locale);
  return (use24h ? day.add_Hm() : day.add_jm()).format(local);
}

/// Shows the live or next coin doubler event on the Rewards tab. Shows nothing when no event is near.
class CoinEventBanner extends StatelessWidget {
  const CoinEventBanner({super.key, required this.schedule, required this.now});

  final CoinEventSchedule schedule;
  final DateTime now;

  /// `<event id>/<phase>` pairs already logged as seen this app session.
  static final Set<String> _seen = <String>{};

  @visibleForTesting
  static void resetSeenForTest() => _seen.clear();

  static void _logSeen(CoinEventWindow window, String phase) {
    if (!_seen.add('${window.id}/$phase')) return;
    unawaited(analytics.track(CoinEventSeenEvent(eventId: window.id, multiplier: window.multiplier, phase: phase)));
  }

  @override
  Widget build(BuildContext context) {
    final CoinEventWindow? live = schedule.liveAt(now);
    final CoinEventWindow? upcoming = live == null ? schedule.nextAfter(now) : null;
    final CoinEventWindow? window = live ?? upcoming;
    if (window == null) return const SizedBox.shrink();
    _logSeen(window, live != null ? 'live' : 'next');

    final l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();
    final bool use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final int m = window.multiplier;
    final bool weekend = window.label == CoinEventLabel.weekend;
    final String title = weekend ? l10n.coinEventTitleWeekend(m) : l10n.coinEventTitle(m);
    final String body;
    final String countdown;
    if (live != null) {
      final String endsAt = formatCoinEventTime(
        live.endsAt.subtract(const Duration(milliseconds: 1)).toLocal(),
        now.toLocal(),
        locale,
        use24h: use24h,
      );
      body = l10n.coinEventLiveBody(m, endsAt);
      countdown = l10n.coinEventEndsIn(formatCountdown(l10n, live.endsAt.difference(now)));
    } else {
      final String startsAt = formatCoinEventTime(window.startsAt.toLocal(), now.toLocal(), locale, use24h: use24h);
      body = l10n.coinEventNextBody(m, startsAt);
      countdown = l10n.coinEventStartsIn(formatCountdown(l10n, window.startsAt.difference(now)));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpace.sm),
      child: Semantics(
        container: true,
        label: '$title. $body $countdown',
        excludeSemantics: true,
        child: Container(
          key: const ValueKey<String>('coin-event-banner'),
          padding: const EdgeInsets.all(PrismSpace.md),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(PrismRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.bolt_rounded, color: cs.primary, size: 24),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: PrismTextStyles.cardTitle(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    Text(body, style: PrismTextStyles.body(context)),
                    const SizedBox(height: PrismSpace.xs),
                    Text(
                      countdown,
                      style: PrismTextStyles.caption(context).copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
