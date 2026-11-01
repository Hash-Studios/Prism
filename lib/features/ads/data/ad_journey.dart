import 'dart:async';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';

/// Local correlation only. Never attach account identifiers or SSV data.
class AdJourney {
  AdJourney(String placement, {this.format = 'rewarded', String? watchId})
    : placement = placement.length > 120 ? placement.substring(0, 120) : placement,
      watchId = watchId ?? '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';

  final String placement;
  final String watchId;
  final String format;

  void record(String outcome, {double? paidValueMicros, String? currency, String? precision}) {
    unawaited(
      analytics.track(
        AdJourneyEvent(
          placement: placement,
          watchId: watchId,
          format: format,
          outcome: outcome,
          paidValueMicros: paidValueMicros,
          currency: currency,
          precision: precision,
        ),
      ),
    );
  }
}
