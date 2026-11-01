import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/ads/data/ad_journey.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  test('journey preserves correlation and paid precision without account or SSV data', () async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
    final journey = AdJourney('download', watchId: 'local-watch');
    journey.record('loaded');
    journey.record('paid', paidValueMicros: 1234, currency: 'INR', precision: 'precise');
    await pumpEventQueue();
    expect(analytics.events.whereType<AdJourneyEvent>().map((event) => event.watchId), ['local-watch', 'local-watch']);
    expect(analytics.events.last.toWireParameters(), {
      'placement': 'download',
      'watch_id': 'local-watch',
      'format': 'rewarded',
      'outcome': 'paid',
      'paid_value_micros': 1234.0,
      'currency': 'INR',
      'precision': 'precise',
    });
  });
}
