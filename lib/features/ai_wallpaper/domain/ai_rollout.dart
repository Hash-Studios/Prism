/// True when Remote Config lets this user generate AI wallpapers. A partial rollout needs a signed-in user.
bool aiRolloutEligible({
  required bool aiEnabled,
  required int rolloutPercent,
  required bool loggedIn,
  required String userId,
}) {
  if (!aiEnabled) return false;
  final int percent = rolloutPercent.clamp(0, 100);
  if (percent >= 100) return true;
  if (!loggedIn) return false;
  final int hash = userId.codeUnits.fold<int>(0, (prev, unit) => (prev + unit) % 100);
  return hash < percent;
}
