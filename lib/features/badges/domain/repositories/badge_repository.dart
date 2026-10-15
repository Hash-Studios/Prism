import 'package:Prism/auth/badge_model.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:flutter/foundation.dart';

class EarnedBadge {
  const EarnedBadge({required this.id, required this.coins});

  final String id;
  final int coins;
}

abstract class BadgeRepository {
  /// Badges earned but not yet shown in the celebrate sheet, oldest first.
  ValueListenable<List<EarnedBadge>> get unseen;

  /// Asks the server to award any badges now earned. Concurrent calls share one request.
  /// On success the session's badges and coin balance are up to date. Returns every badge the user now owns.
  Future<Result<List<Badge>>> check();

  void markSeen(String id);
}
