const Duration wotdResumeRefreshInterval = Duration(minutes: 30);

/// A resume refetches Wall of the Day only when the calendar day changed or enough time has passed.
bool shouldRefreshWotdOnResume({required DateTime? lastRefresh, required DateTime now}) {
  if (lastRefresh == null) {
    return true;
  }
  final bool sameDay = lastRefresh.year == now.year && lastRefresh.month == now.month && lastRefresh.day == now.day;
  return !sameDay || now.difference(lastRefresh) >= wotdResumeRefreshInterval;
}
