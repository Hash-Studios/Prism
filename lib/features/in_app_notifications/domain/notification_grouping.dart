import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
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
  String displayTitle(AppLocalizations l10n) {
    final String title = localizedNotificationCopy(items.first, l10n).title;
    return title.trim().isEmpty ? l10n.notifGenericTitle : title;
  }

  /// Classifies structured notifications first; English text parsing remains for records written by older builds.
  InAppNotificationKind get kind {
    final InAppNotificationKind? structuredKind = items.first.kind;
    if (structuredKind != null) return structuredKind;
    final String title = items.first.title.toLowerCase();
    final String body = items.first.body.toLowerCase();
    if (title.contains('follow') || body.contains('following you') || body.contains('followed you')) {
      return InAppNotificationKind.follower;
    }
    if (body.contains('is now live') && body.contains(' by ')) {
      return InAppNotificationKind.wallLive;
    }
    if (title.contains('wall') && title.contains('approv')) {
      return InAppNotificationKind.wallApproved;
    }
    if (title.contains('wall of the day')) {
      return InAppNotificationKind.wallOfTheDay;
    }
    return InAppNotificationKind.generic;
  }
}

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
String wallOfTheDayRowDayLabel(
  DateTime createdAt, {
  required AppLocalizations l10n,
  required Locale locale,
  DateTime? now,
}) {
  final DateTime local = createdAt.toLocal();
  return switch (_relativeDay(local, (now ?? DateTime.now()).toLocal())) {
    _RelativeDay.today => l10n.notifToday,
    _RelativeDay.yesterday => l10n.notifYesterday,
    _RelativeDay.thisYear => DateFormat.MMMd(locale.toString()).format(local),
    _RelativeDay.earlier => DateFormat.yMMMd(locale.toString()).format(local),
  };
}

/// Time stamp on a notification row: `3:05 PM`, `Yesterday, 3:05 PM`, `Mar 4` or `Mar 4, 2024`.
String notificationTimeLabel(
  DateTime createdAt, {
  required AppLocalizations l10n,
  required Locale locale,
  DateTime? now,
}) {
  final DateTime local = createdAt.toLocal();
  final String time = DateFormat.jm(locale.toString()).format(local);
  return switch (_relativeDay(local, (now ?? DateTime.now()).toLocal())) {
    _RelativeDay.today => time,
    _RelativeDay.yesterday => l10n.notifYesterdayAt(time),
    _RelativeDay.thisYear => DateFormat.MMMd(locale.toString()).format(local),
    _RelativeDay.earlier => DateFormat.yMMMd(locale.toString()).format(local),
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
String groupedListCountActionLine(
  InAppNotificationTitleGroup group, {
  required bool expanded,
  required AppLocalizations l10n,
}) {
  final int n = group.items.length;
  final String action = expanded ? l10n.notifGroupHide : l10n.notifGroupShowAll;
  final String label = switch (group.kind) {
    InAppNotificationKind.follower => l10n.notifGroupFollowers(n),
    InAppNotificationKind.wallLive => l10n.notifGroupWallLive(n),
    InAppNotificationKind.wallApproved => l10n.notifGroupApprovals(n),
    InAppNotificationKind.wallOfTheDay => l10n.notifGroupDailyPicks(n),
    InAppNotificationKind.generic => l10n.notifGroupNotifications(n),
  };
  return l10n.notifGroupCountAction(n, label, action);
}

/// Collapsed preview under the count line (multi-item groups only).
String collapsedGroupSummaryLine(InAppNotificationTitleGroup group, AppLocalizations l10n) {
  final int n = group.items.length;
  final String firstBody = group.items.first.body.trim();
  if (n < 2) {
    if (firstBody.isNotEmpty) {
      return firstBody;
    }
    return group.items.first.title.trim();
  }
  switch (group.kind) {
    case InAppNotificationKind.follower:
      final String? name = followerDisplayNameFromBody(firstBody);
      if (name != null && name.isNotEmpty) {
        return l10n.notifGroupFollowerSummary(name, n - 1);
      }
    case InAppNotificationKind.wallLive || InAppNotificationKind.wallApproved:
      final String? creator = wallLiveCreatorNameFromBody(firstBody);
      if (creator != null && creator.isNotEmpty) {
        return l10n.notifGroupCreatorSummary(creator, n - 1);
      }
      return l10n.notifGroupSeveralCreators;
    case InAppNotificationKind.wallOfTheDay when notificationGroupHasUniformBody(group):
      return l10n.notifGroupDayRows;
    case InAppNotificationKind.wallOfTheDay || InAppNotificationKind.generic:
      break;
  }
  if (firstBody.isEmpty) {
    return l10n.notifGroupSummaryCount(n);
  }
  if (notificationGroupHasUniformBody(group)) {
    return l10n.notifGroupSameMessage(n);
  }
  final String short = firstBody.length > 52 ? '${firstBody.substring(0, 49)}…' : firstBody;
  if (n == 2) {
    return l10n.notifGroupAndMore(short, n - 1);
  }
  return l10n.notifGroupAndMore(short, n - 1);
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
