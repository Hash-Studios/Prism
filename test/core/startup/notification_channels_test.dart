import 'dart:io';

import 'package:Prism/core/startup/notification_channels.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, NotificationChannelSpec> byId = <String, NotificationChannelSpec>{
    for (final NotificationChannelSpec spec in notificationChannelSpecs) spec.id: spec,
  };

  test('every channel id in the backend has a channel', () {
    final RegExp pattern = RegExp(r'''(?:channelId:|CHANNEL_ID =)\s*["'](\w+)["']''');
    final Set<String> serverIds = <String>{
      for (final FileSystemEntity file in Directory('functions/src').listSync())
        if (file is File && file.path.endsWith('.ts'))
          for (final RegExpMatch match in pattern.allMatches(file.readAsStringSync())) match.group(1)!,
    };

    expect(serverIds, containsAll(<String>['moderation', 'followers', 'posts', 'wall_of_the_day', 'streak_reminder']));
    expect(byId.keys, containsAll(serverIds));
  });

  test('the moderation channel exists', () {
    expect(byId['moderation']?.name, 'Moderation');
  });

  test('channels whose pushes are sent with high priority allow a heads-up banner', () {
    for (final String id in <String>['followers', 'wall_of_the_day', 'streak_reminder', 'moderation']) {
      expect(byId[id]?.importance, Importance.high, reason: id);
    }
  });

  test('channel ids are unique and downloads stay quiet', () {
    expect(byId.length, notificationChannelSpecs.length);
    expect(byId['downloads']?.playSound, isFalse);
  });
}
