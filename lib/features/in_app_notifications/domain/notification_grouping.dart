import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:intl/intl.dart';

/// Key used to merge notifications that share the same trimmed title.
String _groupKey(String title) {
  final t = title.trim();
  return t.isEmpty ? '__untitled__' : t;
}

/// Notifications that share one title, ordered newest-first within the group.
class InAppNotificationTitleGroup {
  const InAppNotificationTitleGroup({required this.key, required this.items});

  final String key;
  final List<InAppNotificationEntity> items;

  bool get isSingle => items.length == 1;

  int get unreadCount => items.where((InAppNotificationEntity e) => !e.read).length;

  /// Row title: first item’s title, or a generic label when empty.
  String get displayTitle {
    final t = items.first.title.trim();
    return t.isEmpty ? 'Notification' : items.first.title;
  }

  /// What kind of push this group holds, guessed from its title and body wording.
  NotificationKind get kind {
    final String title = displayTitle.toLowerCase();
    final String body = items.first.body.toLowerCase();
    if (title.contains('follow') || body.contains('following you') || body.contains('followed you')) {
      return NotificationKind.follower;
    }
    if (body.contains('is now live') && body.contains(' by ')) {
      return NotificationKind.wallLive;
    }
    if (title.contains('wall') && title.contains('approv')) {
      return NotificationKind.wallApproved;
    }
    if (title.contains('wall of the day')) {
      return NotificationKind.wallOfTheDay;
    }
    return NotificationKind.generic;
  }
}

enum NotificationKind { follower, wallLive, wallApproved, wallOfTheDay, generic }

/// Creator segment from `"Title" by Name is now live.` (best-effort).
String? wallLiveCreatorNameFromBody(String body) {
  final String trimmed = body.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final RegExpMatch? match = RegExp(r'\bby\s+(.+?)\s+is\s+now\s+live\.?', caseSensitive: false).firstMatch(trimmed);
  return match?.group(1)?.trim();
}

/// Every item shares the same body (e.g. repeated “Check it out”).
bool notificationGroupHasUniformBody(InAppNotificationTitleGroup group) {
  final String first = group.items.first.body.trim();
  for (final InAppNotificationEntity e in group.items) {
    if (e.body.trim() != first) {
      return false;
    }
  }
  return first.isNotEmpty;
}

enum _RelativeDay { today, yesterday, thisYear, earlier }

_RelativeDay _relativeDay(DateTime local, DateTime now) {
  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (sameDay(local, now)) {
    return _RelativeDay.today;
  }
  if (sameDay(local, now.subtract(const Duration(days: 1)))) {
    return _RelativeDay.yesterday;
  }
  return local.year == now.year ? _RelativeDay.thisYear : _RelativeDay.earlier;
}

/// Short day label for WOTD child rows (avoids repeating identical body text).
String wallOfTheDayRowDayLabel(DateTime createdAt, {DateTime? now}) {
  final DateTime local = createdAt.toLocal();
  return switch (_relativeDay(local, (now ?? DateTime.now()).toLocal())) {
    _RelativeDay.today => 'Today',
    _RelativeDay.yesterday => 'Yesterday',
    _RelativeDay.thisYear => DateFormat.MMMd().format(local),
    _RelativeDay.earlier => DateFormat.yMMMd().format(local),
  };
}

/// Time stamp on a notification row: `3:05 PM`, `Yesterday, 3:05 PM`, `Mar 4` or `Mar 4, 2024`.
String notificationTimeLabel(DateTime createdAt, {DateTime? now}) {
  final DateTime local = createdAt.toLocal();
  final String time = DateFormat('h:mm a').format(local);
  return switch (_relativeDay(local, (now ?? DateTime.now()).toLocal())) {
    _RelativeDay.today => time,
    _RelativeDay.yesterday => 'Yesterday, $time',
    _RelativeDay.thisYear => DateFormat.MMMd().format(local),
    _RelativeDay.earlier => DateFormat.yMMMd().format(local),
  };
}

/// Parses `"Name is now following you."` → display name; null if pattern unknown.
String? followerDisplayNameFromBody(String body) {
  final String trimmed = body.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'^(.+?)\s+is\s+now\s+following\s+you\.?',
    caseSensitive: false,
  ).firstMatch(trimmed);
  return match?.group(1)?.trim();
}

/// Second line under the group title: contextual count + expand/collapse action.
String groupedListCountActionLine(InAppNotificationTitleGroup group, {required bool expanded}) {
  final int n = group.items.length;
  final String action = expanded ? 'Hide' : 'Show all';
  final String label = switch (group.kind) {
    NotificationKind.follower => n == 1 ? 'new follower' : 'new followers',
    NotificationKind.wallLive => n == 1 ? 'wall went live' : 'walls went live',
    NotificationKind.wallApproved => n == 1 ? 'approval' : 'approvals',
    NotificationKind.wallOfTheDay => n == 1 ? 'daily pick' : 'daily picks',
    NotificationKind.generic => n == 1 ? 'notification' : 'notifications',
  };
  return '$n $label · $action';
}

/// Collapsed preview under the count line (multi-item groups only).
String collapsedGroupSummaryLine(InAppNotificationTitleGroup group) {
  final int n = group.items.length;
  final String firstBody = group.items.first.body.trim();
  if (n < 2) {
    if (firstBody.isNotEmpty) {
      return firstBody;
    }
    return group.items.first.title.trim();
  }
  switch (group.kind) {
    case NotificationKind.follower:
      final String? name = followerDisplayNameFromBody(firstBody);
      if (name != null && name.isNotEmpty) {
        return n == 2 ? '$name and 1 other followed you.' : '$name and ${n - 1} others followed you.';
      }
    case NotificationKind.wallLive || NotificationKind.wallApproved:
      final String? creator = wallLiveCreatorNameFromBody(firstBody);
      if (creator != null && creator.isNotEmpty) {
        return n == 2 ? 'From $creator and 1 other creator.' : 'From $creator and ${n - 1} other creators.';
      }
      return 'Several creators—expand to see each wall.';
    case NotificationKind.wallOfTheDay when notificationGroupHasUniformBody(group):
      return 'Each row is a different day; times are on the right.';
    case NotificationKind.wallOfTheDay || NotificationKind.generic:
      break;
  }
  if (firstBody.isEmpty) {
    return '$n notifications in this group.';
  }
  if (notificationGroupHasUniformBody(group)) {
    return 'Same message sent $n times—compare timestamps to see when.';
  }
  final String short = firstBody.length > 52 ? '${firstBody.substring(0, 49)}…' : firstBody;
  if (n == 2) {
    return '$short and 1 more.';
  }
  return '$short and ${n - 1} more.';
}

/// Expects [sortedNewestFirst] (e.g. from repository). Returns groups sorted by
/// each group’s newest [createdAt].
List<InAppNotificationTitleGroup> groupInAppNotificationsByTitle(List<InAppNotificationEntity> sortedNewestFirst) {
  if (sortedNewestFirst.isEmpty) {
    return const <InAppNotificationTitleGroup>[];
  }
  final map = <String, List<InAppNotificationEntity>>{};
  for (final InAppNotificationEntity n in sortedNewestFirst) {
    map.putIfAbsent(_groupKey(n.title), () => <InAppNotificationEntity>[]).add(n);
  }
  for (final List<InAppNotificationEntity> list in map.values) {
    list.sort((InAppNotificationEntity a, InAppNotificationEntity b) => b.createdAt.compareTo(a.createdAt));
  }
  final List<InAppNotificationTitleGroup> groups = map.entries
      .map(
        (MapEntry<String, List<InAppNotificationEntity>> e) => InAppNotificationTitleGroup(key: e.key, items: e.value),
      )
      .toList(growable: false);
  groups.sort(
    (InAppNotificationTitleGroup a, InAppNotificationTitleGroup b) =>
        b.items.first.createdAt.compareTo(a.items.first.createdAt),
  );
  return groups;
}
