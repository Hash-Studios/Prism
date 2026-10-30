import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/weekly_challenges/biz/challenge_admission_tracker.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

void main() {
  test('tracks entered only after server confirmation, dedupes and keeps source after restart', () async {
    final store = InMemoryLocalStore();
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    app_state.prismUser = constants.createGuestPrismUser()
      ..id = 'creator'
      ..loggedIn = true;
    addTearDown(() {
      AnalyticsRuntime.reset();
      app_state.prismUser = constants.createGuestPrismUser();
    });
    final first = ChallengeAdmissionTracker(store);
    await first.submitted(
      uid: 'creator',
      challengeId: '2026-10-26',
      wallId: 'wall_1',
      source: ChallengeEntrySource.upload,
    );
    expect(analytics.events, isEmpty);
    await first.confirm('2026-10-26', []);
    expect(analytics.events, isEmpty);
    final restarted = ChallengeAdmissionTracker(store);
    await restarted.confirm('2026-10-26', ['wall_1']);
    await restarted.confirm('2026-10-26', ['wall_1']);
    expect(analytics.events.single.eventName, 'challenge_entered');
    expect(analytics.events.single.toWireParameters(), {'challenge_id': '2026-10-26', 'source': 'upload'});
    await restarted.submitted(
      uid: 'creator',
      challengeId: '2026-10-26',
      wallId: 'wall_2',
      source: ChallengeEntrySource.ai,
    );
    app_state.prismUser.id = 'other';
    await restarted.confirm('2026-10-26', ['wall_2']);
    expect(analytics.events, hasLength(1));
    app_state.prismUser.id = 'creator';
    await restarted.confirm('2026-10-26', ['wall_2']);
    expect(analytics.events, hasLength(2));
    expect(analytics.events.last.toWireParameters(), {'challenge_id': '2026-10-26', 'source': 'ai'});
  });
}
