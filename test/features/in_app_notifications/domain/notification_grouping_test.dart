import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

import '../in_app_notification_fixture.dart';

InAppNotificationTitleGroup _group(List<InAppNotificationEntity> newestFirst) =>
    InAppNotificationTitleGroup(key: 'k', items: newestFirst);

InAppNotificationEntity _follower(String id, String name, DateTime createdAt) =>
    notification(id, title: 'You have a new follower! 🎉', body: '$name is now following you.', createdAt: createdAt);

void main() {
  test('groupInAppNotificationsByTitle merges same title and sorts by newest in group', () {
    final older = notification('a', title: 'New follower', body: 'u1', createdAt: DateTime.utc(2024));
    final newer = notification('b', title: 'New follower', body: 'u2', createdAt: DateTime.utc(2024, 2), read: true);
    final other = notification('c', title: 'Sale', body: 'x', createdAt: DateTime.utc(2024, 3));

    final groups = groupInAppNotificationsByTitle(<InAppNotificationEntity>[older, other, newer]);

    expect(groups.length, 2);
    expect(groups.first.key, 'Sale');
    expect(groups.first.items, <InAppNotificationEntity>[other]);
    final followerGroup = groups.singleWhere((g) => g.key == 'New follower');
    expect(followerGroup.items.map((e) => e.id), <String>['b', 'a']);
  });

  test('titles are trimmed for grouping and blank titles share one group', () {
    final groups = groupInAppNotificationsByTitle(<InAppNotificationEntity>[
      notification('a', title: '  Hi  ', createdAt: DateTime.utc(2024, 1, 3)),
      notification('b', title: 'Hi', createdAt: DateTime.utc(2024, 1, 2)),
      notification('c', title: '', createdAt: DateTime.utc(2024)),
      notification('d', title: '   ', createdAt: DateTime.utc(2023)),
    ]);

    expect(groups.map((g) => g.key), <String>['Hi', '__untitled__']);
    expect(groups.last.items, hasLength(2));
    expect(groups.last.displayTitle, 'Notification');
  });

  test('followerDisplayNameFromBody parses standard follower sentence', () {
    expect(followerDisplayNameFromBody('Joanan Boneu is now following you.'), 'Joanan Boneu');
    expect(followerDisplayNameFromBody('  Tapas Baidya is now following you'), 'Tapas Baidya');
    expect(followerDisplayNameFromBody('No match here'), isNull);
  });

  group('kind', () {
    NotificationKind kindOf(String title, String body) =>
        _group(<InAppNotificationEntity>[notification('1', title: title, body: body)]).kind;

    test('follower wins over wall wording', () {
      expect(kindOf('You have a new follower! 🎉', 'A is now following you.'), NotificationKind.follower);
      expect(kindOf('Hello', 'B followed you yesterday'), NotificationKind.follower);
      expect(kindOf('Follow news', '"Wall" by C is now live.'), NotificationKind.follower);
    });

    test('wall notifications are told apart by body and title', () {
      expect(kindOf('Wall approved ✅', '"Untitled" by Diogo is now live.'), NotificationKind.wallLive);
      expect(kindOf('Wall approved ✅', 'Nice work'), NotificationKind.wallApproved);
      expect(kindOf("Today's Wall of the Day is here", 'Check it out'), NotificationKind.wallOfTheDay);
      expect(kindOf('Weekly drop', 'New walls added'), NotificationKind.generic);
    });
  });

  test('groupedListCountActionLine adds follower vs generic context', () {
    final followers = _group(<InAppNotificationEntity>[
      _follower('1', 'A', DateTime.utc(2024, 1, 2)),
      _follower('2', 'B', DateTime.utc(2024)),
    ]);
    expect(groupedListCountActionLine(followers, expanded: false), '2 new followers · Show all');
    expect(groupedListCountActionLine(followers, expanded: true), '2 new followers · Hide');

    final generic = _group(<InAppNotificationEntity>[
      notification('x', title: 'Weekly drop', body: 'New walls added'),
      notification('y', title: 'Weekly drop', body: 'More walls'),
    ]);
    expect(groupedListCountActionLine(generic, expanded: false), '2 notifications · Show all');
  });

  test('collapsedGroupSummaryLine summarizes followers and generic groups', () {
    final followers = _group(<InAppNotificationEntity>[
      _follower('newest', 'First User', DateTime.utc(2024, 1, 10)),
      _follower('mid', 'Second', DateTime.utc(2024, 1, 5)),
      _follower('old', 'Third', DateTime.utc(2024)),
    ]);
    expect(collapsedGroupSummaryLine(followers), 'First User and 2 others followed you.');

    final generic = _group(<InAppNotificationEntity>[
      notification('a', title: 'News', body: 'Short line one'),
      notification('b', title: 'News', body: 'Line two'),
    ]);
    expect(collapsedGroupSummaryLine(generic), 'Short line one and 1 more.');
  });

  test('wallLiveCreatorNameFromBody parses quoted title pattern', () {
    expect(wallLiveCreatorNameFromBody('"Untitled" by Diogo López is now live.'), 'Diogo López');
    expect(wallLiveCreatorNameFromBody('by Someone is now live'), 'Someone');
  });

  test('wall approved live groups get walls count and creator summary', () {
    final wallGroup = _group(<InAppNotificationEntity>[
      notification('n', title: 'Wall approved ✅', body: '"Untitled" by Diogo López is now live.'),
      notification('o', title: 'Wall approved ✅', body: '"Sunset" by Other is now live.'),
    ]);
    expect(groupedListCountActionLine(wallGroup, expanded: false), '2 walls went live · Show all');
    expect(collapsedGroupSummaryLine(wallGroup), 'From Diogo López and 1 other creator.');
    expect(notificationGroupHasUniformBody(wallGroup), isFalse);
  });

  test('Wall of the Day uniform body uses daily picks count and day-based summary', () {
    final wotd = _group(<InAppNotificationEntity>[
      notification('1', title: "Today's Wall of the Day is here", body: 'Check it out'),
      notification('2', title: "Today's Wall of the Day is here", body: 'Check it out'),
    ]);
    expect(groupedListCountActionLine(wotd, expanded: false), '2 daily picks · Show all');
    expect(collapsedGroupSummaryLine(wotd), 'Each row is a different day; times are on the right.');
    expect(notificationGroupHasUniformBody(wotd), isTrue);
  });

  test('uniform non-WOTD bodies avoid snippet plus N more duplication', () {
    final dup = _group(<InAppNotificationEntity>[
      notification('a', title: 'Reminder', body: 'Please update'),
      notification('b', title: 'Reminder', body: 'Please update'),
    ]);
    expect(collapsedGroupSummaryLine(dup), 'Same message sent 2 times—compare timestamps to see when.');
  });

  group('time labels', () {
    final now = DateTime(2024, 6, 15, 18);

    test('today shows the time, yesterday adds a prefix', () {
      expect(notificationTimeLabel(DateTime(2024, 6, 15, 9, 5), now: now), '9:05 AM');
      expect(notificationTimeLabel(DateTime(2024, 6, 14, 23, 30), now: now), 'Yesterday, 11:30 PM');
      expect(wallOfTheDayRowDayLabel(DateTime(2024, 6, 15, 9), now: now), 'Today');
      expect(wallOfTheDayRowDayLabel(DateTime(2024, 6, 14, 9), now: now), 'Yesterday');
    });

    test('the same day of an earlier month is a dated label, not a bare time', () {
      expect(notificationTimeLabel(DateTime(2024, 5, 15, 9, 5), now: now), 'May 15');
      expect(notificationTimeLabel(DateTime(2023, 6, 15, 9, 5), now: now), 'Jun 15, 2023');
    });

    test('yesterday works across a month boundary', () {
      final firstOfMonth = DateTime(2024, 7, 1, 8);
      expect(notificationTimeLabel(DateTime(2024, 6, 30, 22), now: firstOfMonth), 'Yesterday, 10:00 PM');
    });
  });
}
