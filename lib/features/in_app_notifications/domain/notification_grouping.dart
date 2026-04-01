import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:intl/intl.dart';

/// Key used to merge notifications that share the same trimmed title.
String inAppNotificationGroupKey(String title) {
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
}

/// Heuristic: follower-style push (title or body wording).
bool notificationGroupLooksLikeFollowers(InAppNotificationTitleGroup group) {
  final String title = group.displayTitle.toLowerCase();
  if (title.contains('follow')) {
    return true;
  }
  final String body = group.items.first.body.toLowerCase();
  return body.contains('following you') || body.contains('followed you');
}

bool _wallLiveBodyPattern(String body) {
  final String b = body.toLowerCase();
  return b.contains('is now live') && b.contains(' by ');
}

/// Wall approved / “is now live” setup notifications (distinct from generic merges).
bool notificationGroupLooksLikeWallApprovedLive(InAppNotificationTitleGroup group) {
  if (notificationGroupLooksLikeFollowers(group)) {
    return false;
  }
  final String title = group.displayTitle.toLowerCase();
  final String body = group.items.first.body;
  if (_wallLiveBodyPattern(body)) {
    return true;
  }
  return title.contains('wall') && title.contains('approv');
}

/// Creator segment from `"Title" by Name is now live.` (best-effort).
String? wallLiveCreatorNameFromBody(String body) {
  final String trimmed = body.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'\bby\s+(.+?)\s+is\s+now\s+live\.?',
    caseSensitive: false,
  ).firstMatch(trimmed);
  return match?.group(1)?.trim();
}

/// Today’s Wall of the Day–style recurring title.
bool notificationGroupLooksLikeWallOfTheDay(InAppNotificationTitleGroup group) {
  if (notificationGroupLooksLikeFollowers(group)) {
    return false;
  }
  final String title = group.displayTitle.toLowerCase();
  return title.contains('wall of the day');
}

/// Every item shares the same body (e.g. repeated “Check it out”).
bool notificationGroupHasUniformBody(InAppNotificationTitleGroup group) {
  if (group.items.isEmpty) {
    return true;
  }
  final String first = group.items.first.body.trim();
  for (final InAppNotificationEntity e in group.items) {
    if (e.body.trim() != first) {
      return false;
    }
  }
  return first.isNotEmpty;
}

/// Short day label for WOTD child rows (avoids repeating identical body text).
String wallOfTheDayRowDayLabel(DateTime createdAt) {
  final DateTime local = createdAt.toLocal();
  final DateTime now = DateTime.now().toLocal();
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return 'Today';
  }
  final DateTime yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) {
    return 'Yesterday';
  }
  if (local.year == now.year) {
    return DateFormat.MMMd().format(local);
  }
  return DateFormat.yMMMd().format(local);
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
  if (notificationGroupLooksLikeFollowers(group)) {
    final String label = n == 1 ? 'new follower' : 'new followers';
    return '$n $label · $action';
  }
  if (notificationGroupLooksLikeWallApprovedLive(group)) {
    if (_wallLiveBodyPattern(group.items.first.body)) {
      final String label = n == 1 ? 'wall went live' : 'walls went live';
      return '$n $label · $action';
    }
    final String label = n == 1 ? 'approval' : 'approvals';
    return '$n $label · $action';
  }
  if (notificationGroupLooksLikeWallOfTheDay(group)) {
    final String label = n == 1 ? 'daily pick' : 'daily picks';
    return '$n $label · $action';
  }
  final String label = n == 1 ? 'notification' : 'notifications';
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
  if (notificationGroupLooksLikeFollowers(group)) {
    final String? name = followerDisplayNameFromBody(firstBody);
    if (name != null && name.isNotEmpty) {
      if (n == 2) {
        return '$name and 1 other followed you.';
      }
      return '$name and ${n - 1} others followed you.';
    }
  }
  if (notificationGroupLooksLikeWallApprovedLive(group)) {
    final String? creator = wallLiveCreatorNameFromBody(firstBody);
    if (creator != null && creator.isNotEmpty) {
      if (n == 2) {
        return 'From $creator and 1 other creator.';
      }
      return 'From $creator and ${n - 1} other creators.';
    }
    return 'Several creators—expand to see each wall.';
  }
  if (notificationGroupLooksLikeWallOfTheDay(group) && notificationGroupHasUniformBody(group)) {
    return 'Each row is a different day; times are on the right.';
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
/// each group’s newest [createdAt] (same order as before for ungrouped items).
List<InAppNotificationTitleGroup> groupInAppNotificationsByTitle(
  List<InAppNotificationEntity> sortedNewestFirst,
) {
  if (sortedNewestFirst.isEmpty) {
    return const <InAppNotificationTitleGroup>[];
  }
  final map = <String, List<InAppNotificationEntity>>{};
  for (final InAppNotificationEntity n in sortedNewestFirst) {
    map.putIfAbsent(inAppNotificationGroupKey(n.title), () => <InAppNotificationEntity>[]).add(n);
  }
  for (final List<InAppNotificationEntity> list in map.values) {
    list.sort((InAppNotificationEntity a, InAppNotificationEntity b) => b.createdAt.compareTo(a.createdAt));
  }
  final List<InAppNotificationTitleGroup> groups = map.entries
      .map(
        (MapEntry<String, List<InAppNotificationEntity>> e) =>
            InAppNotificationTitleGroup(key: e.key, items: e.value),
      )
      .toList(growable: false);
  groups.sort(
    (InAppNotificationTitleGroup a, InAppNotificationTitleGroup b) =>
        b.items.first.createdAt.compareTo(a.items.first.createdAt),
  );
  return groups;
}
