import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groupInAppNotificationsByTitle merges same title and sorts by newest in group', () {
    final older = InAppNotificationEntity(
      id: 'a',
      title: 'New follower',
      pageName: '',
      body: 'u1',
      imageUrl: '',
      arguments: const <Object>[],
      url: '',
      createdAt: DateTime.utc(2024, 1, 1),
      read: false,
    );
    final newer = InAppNotificationEntity(
      id: 'b',
      title: 'New follower',
      pageName: '',
      body: 'u2',
      imageUrl: '',
      arguments: const <Object>[],
      url: '',
      createdAt: DateTime.utc(2024, 2, 1),
      read: true,
    );
    final other = InAppNotificationEntity(
      id: 'c',
      title: 'Sale',
      pageName: '',
      body: 'x',
      imageUrl: '',
      arguments: const <Object>[],
      url: '',
      createdAt: DateTime.utc(2024, 3, 1),
      read: false,
    );

    final input = <InAppNotificationEntity>[older, other, newer];
    final groups = groupInAppNotificationsByTitle(input);

    expect(groups.length, 2);
    expect(groups.first.key, inAppNotificationGroupKey('Sale'));
    expect(groups.first.items, <InAppNotificationEntity>[other]);
    final followerGroup = groups.singleWhere((g) => g.key == inAppNotificationGroupKey('New follower'));
    expect(followerGroup.items.length, 2);
    expect(followerGroup.items.first.id, 'b');
    expect(followerGroup.items.last.id, 'a');
  });

  test('inAppNotificationGroupKey trims and maps empty to sentinel', () {
    expect(inAppNotificationGroupKey('  Hi  '), 'Hi');
    expect(inAppNotificationGroupKey(''), '__untitled__');
    expect(inAppNotificationGroupKey('   '), '__untitled__');
  });

  test('followerDisplayNameFromBody parses standard follower sentence', () {
    expect(followerDisplayNameFromBody('Joanan Boneu is now following you.'), 'Joanan Boneu');
    expect(followerDisplayNameFromBody('  Tapas Baidya is now following you'), 'Tapas Baidya');
    expect(followerDisplayNameFromBody('No match here'), isNull);
  });

  test('groupedListCountActionLine adds follower vs generic context', () {
    final InAppNotificationTitleGroup followers = InAppNotificationTitleGroup(
      key: 'k',
      items: <InAppNotificationEntity>[
        InAppNotificationEntity(
          id: '1',
          title: 'You have a new follower! 🎉',
          pageName: '',
          body: 'A is now following you.',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 1, 2),
          read: false,
        ),
        InAppNotificationEntity(
          id: '2',
          title: 'You have a new follower! 🎉',
          pageName: '',
          body: 'B is now following you.',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 1, 1),
          read: true,
        ),
      ],
    );
    expect(groupedListCountActionLine(followers, expanded: false), '2 new followers · Show all');
    expect(groupedListCountActionLine(followers, expanded: true), '2 new followers · Hide');

    final InAppNotificationTitleGroup generic = InAppNotificationTitleGroup(
      key: 'g',
      items: <InAppNotificationEntity>[
        InAppNotificationEntity(
          id: 'x',
          title: 'Weekly drop',
          pageName: '',
          body: 'New walls added',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 1, 2),
          read: false,
        ),
        InAppNotificationEntity(
          id: 'y',
          title: 'Weekly drop',
          pageName: '',
          body: 'More walls',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 1, 1),
          read: true,
        ),
      ],
    );
    expect(groupedListCountActionLine(generic, expanded: false), '2 notifications · Show all');
  });

  test('collapsedGroupSummaryLine summarizes followers and generic groups', () {
    // Newest first (matches [groupInAppNotificationsByTitle] ordering).
    final InAppNotificationTitleGroup g = InAppNotificationTitleGroup(
      key: 'f',
      items: <InAppNotificationEntity>[
        InAppNotificationEntity(
          id: 'newest',
          title: 'Follow',
          pageName: '',
          body: 'First User is now following you.',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 1, 10),
          read: false,
        ),
        InAppNotificationEntity(
          id: 'mid',
          title: 'Follow',
          pageName: '',
          body: 'Second is now following you.',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 1, 5),
          read: false,
        ),
        InAppNotificationEntity(
          id: 'old',
          title: 'Follow',
          pageName: '',
          body: 'Third is now following you.',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 1, 1),
          read: false,
        ),
      ],
    );
    expect(collapsedGroupSummaryLine(g), 'First User and 2 others followed you.');

    final InAppNotificationTitleGroup generic = InAppNotificationTitleGroup(
      key: 'x',
      items: <InAppNotificationEntity>[
        InAppNotificationEntity(
          id: 'a',
          title: 'News',
          pageName: '',
          body: 'Short line one',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 2, 2),
          read: false,
        ),
        InAppNotificationEntity(
          id: 'b',
          title: 'News',
          pageName: '',
          body: 'Line two',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 2, 1),
          read: true,
        ),
      ],
    );
    expect(collapsedGroupSummaryLine(generic), 'Short line one and 1 more.');
  });

  test('wallLiveCreatorNameFromBody parses quoted title pattern', () {
    expect(wallLiveCreatorNameFromBody('"Untitled" by Diogo López is now live.'), 'Diogo López');
    expect(wallLiveCreatorNameFromBody('by Someone is now live'), 'Someone');
  });

  test('wall approved live groups get walls count and creator summary', () {
    final InAppNotificationTitleGroup wallGroup = InAppNotificationTitleGroup(
      key: 'w',
      items: <InAppNotificationEntity>[
        InAppNotificationEntity(
          id: 'n',
          title: 'Wall approved ✅',
          pageName: '',
          body: '"Untitled" by Diogo López is now live.',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 6, 2),
          read: false,
        ),
        InAppNotificationEntity(
          id: 'o',
          title: 'Wall approved ✅',
          pageName: '',
          body: '"Sunset" by Other is now live.',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 6, 1),
          read: true,
        ),
      ],
    );
    expect(groupedListCountActionLine(wallGroup, expanded: false), '2 walls went live · Show all');
    expect(collapsedGroupSummaryLine(wallGroup), 'From Diogo López and 1 other creator.');
    expect(notificationGroupHasUniformBody(wallGroup), isFalse);
  });

  test('Wall of the Day uniform body uses daily picks count and day-based summary', () {
    final InAppNotificationTitleGroup wotd = InAppNotificationTitleGroup(
      key: 'd',
      items: <InAppNotificationEntity>[
        InAppNotificationEntity(
          id: '1',
          title: "Today's Wall of the Day is here",
          pageName: '',
          body: 'Check it out',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 7, 10),
          read: false,
        ),
        InAppNotificationEntity(
          id: '2',
          title: "Today's Wall of the Day is here",
          pageName: '',
          body: 'Check it out',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 7, 9),
          read: true,
        ),
      ],
    );
    expect(groupedListCountActionLine(wotd, expanded: false), '2 daily picks · Show all');
    expect(collapsedGroupSummaryLine(wotd), 'Each row is a different day; times are on the right.');
    expect(notificationGroupHasUniformBody(wotd), isTrue);
  });

  test('uniform non-WOTD bodies avoid snippet plus N more duplication', () {
    final InAppNotificationTitleGroup dup = InAppNotificationTitleGroup(
      key: 'u',
      items: <InAppNotificationEntity>[
        InAppNotificationEntity(
          id: 'a',
          title: 'Reminder',
          pageName: '',
          body: 'Please update',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 8, 2),
          read: false,
        ),
        InAppNotificationEntity(
          id: 'b',
          title: 'Reminder',
          pageName: '',
          body: 'Please update',
          imageUrl: '',
          arguments: const <Object>[],
          url: '',
          createdAt: DateTime.utc(2024, 8, 1),
          read: true,
        ),
      ],
    );
    expect(collapsedGroupSummaryLine(dup), 'Same message sent 2 times—compare timestamps to see when.');
  });
}
