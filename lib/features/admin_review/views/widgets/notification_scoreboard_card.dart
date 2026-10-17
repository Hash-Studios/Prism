import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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
      final List<ScoreboardDay> days = await firestoreClient.query(
        const FirestoreQuerySpec(
          collection: _scoreboardDays,
          sourceTag: 'admin.notification_scoreboard',
          orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: firestoreDocumentIdField, descending: true)],
          limit: 14,
        ),
        (Map<String, dynamic> data, String id) => ScoreboardDay.fromMap(id, data),
      );
      if (!mounted) return;
      setState(() {
        _days = days;
        _error = null;
      });
    } catch (error, stackTrace) {
      logger.w('Notification scoreboard failed to load.', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _error = 'Could not load notification counts.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ScoreboardDay>? days = _days;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Last 14 days', style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Text(
            'Accepted means Firebase took the push. A push to the account topic and the device token counts twice. It is not a view.',
            style: PrismTextStyles.caption(context),
          ),
          const SizedBox(height: PrismSpace.sm),
          if (_error != null)
            Text(_error!, style: PrismTextStyles.body(context))
          else if (days == null)
            Text('Loading notification counts.', style: PrismTextStyles.caption(context))
          else if (days.isEmpty)
            Text('No notification counts yet.', style: PrismTextStyles.body(context))
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
