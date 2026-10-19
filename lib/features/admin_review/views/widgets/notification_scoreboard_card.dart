import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/scoreboard_row.dart';
import 'package:flutter/material.dart';

const String _scoreboardDays = 'metrics/notificationScoreboard/days';

/// Last 14 UTC days of push counts. Accepted means Firebase took the push.
class NotificationScoreboardCard extends StatefulWidget {
  const NotificationScoreboardCard({super.key});

  @override
  State<NotificationScoreboardCard> createState() => _NotificationScoreboardCardState();
}

class _NotificationScoreboardCardState extends State<NotificationScoreboardCard> {
  List<ScoreboardDay>? _days;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ScoreboardWindow window = scoreboardWindow(DateTime.now().toUtc());
      final List<ScoreboardDay> shards = await firestoreClient.query(
        FirestoreQuerySpec(
          collection: _scoreboardDays,
          sourceTag: 'admin.notification_scoreboard',
          filters: <FirestoreFilter>[
            FirestoreFilter(
              field: firestoreDocumentIdField,
              op: FirestoreFilterOp.isGreaterThanOrEqualTo,
              value: window.start,
            ),
            FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isLessThan, value: window.end),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: firestoreDocumentIdField, descending: true)],
          limit: window.limit,
        ),
        (Map<String, dynamic> data, String id) => ScoreboardDay.fromMap(id, data),
      );
      final List<ScoreboardDay> days = combineScoreboardShards(shards);
      if (!mounted) return;
      setState(() {
        _days = days;
        _error = null;
      });
    } catch (error, stackTrace) {
      logger.w('Notification scoreboard failed to load.', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _error = context.l10n.adminNotificationCountsLoadError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ScoreboardDay>? days = _days;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(context.l10n.adminLast14Days, style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Text(context.l10n.adminNotificationCountExplanation, style: PrismTextStyles.caption(context)),
          const SizedBox(height: PrismSpace.sm),
          if (_error != null)
            Text(_error!, style: PrismTextStyles.body(context))
          else if (days == null)
            Text(context.l10n.adminLoadingNotificationCounts, style: PrismTextStyles.caption(context))
          else if (days.isEmpty)
            Text(context.l10n.adminNoNotificationCounts, style: PrismTextStyles.body(context))
          else
            for (final ScoreboardDay day in days) ...<Widget>[
              Text(formatScoreboardLine(day), style: PrismTextStyles.caption(context)),
              const SizedBox(height: PrismSpace.xxs),
            ],
        ],
      ),
    );
  }
}
