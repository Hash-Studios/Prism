import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ChallengeAdmissionTracker {
  ChallengeAdmissionTracker(this._store);
  final LocalStore _store;
  final Set<String> _reporting = {};
  static String _key(String uid, String challengeId, String wallId) => 'challenge.entry.$uid.$challengeId.$wallId';
  Future<void> submitted({
    required String uid,
    required String challengeId,
    required String wallId,
    required ChallengeEntrySource source,
  }) async {
    if (uid.isEmpty || challengeId.isEmpty || wallId.isEmpty) return;
    final key = _key(uid, challengeId, wallId);
    if (_store.get(key) == 'reported') return;
    await _store.set(key, source.name);
  }

  Future<void> confirm(String challengeId, List<String> admittedWallIds) async {
    final uid = app_state.prismUser.id;
    if (!app_state.prismUser.loggedIn || uid.isEmpty) return;
    for (final wallId in admittedWallIds) {
      final key = _key(uid, challengeId, wallId);
      final value = _store.get(key);
      if ((value != 'upload' && value != 'ai') || !_reporting.add(key)) continue;
      try {
        await analytics.track(
          ChallengeEnteredEvent(
            challengeId: challengeId,
            source: value == 'ai' ? ChallengeEntrySource.ai : ChallengeEntrySource.upload,
          ),
        );
        await _store.set(key, 'reported');
      } finally {
        _reporting.remove(key);
      }
    }
  }
}
