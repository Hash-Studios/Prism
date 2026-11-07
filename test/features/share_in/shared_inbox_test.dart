import 'dart:io';

import 'package:Prism/features/share_in/data/shared_inbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory inboxDir;
  late Directory handOffDir;
  late SharedInbox inbox;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('share_in_inbox_test_');
    inboxDir = Directory(p.join(root.path, 'inbox'))..createSync();
    handOffDir = Directory(p.join(root.path, 'hand_off'))..createSync();
    inbox = SharedInbox(inboxDirectory: () async => inboxDir, handOffDirectory: () async => handOffDir);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File writeFile(Directory folder, String name, {List<int> bytes = const <int>[1, 2, 3]}) {
    return File(p.join(folder.path, name))..writeAsBytesSync(bytes);
  }

  group('handOff', () {
    test('moves a file from the inbox to the hand-off folder', () async {
      final File source = writeFile(inboxDir, 'photo.png', bytes: <int>[9, 8, 7]);

      final File moved = await inbox.handOff(source.path);

      expect(source.existsSync(), isFalse);
      expect(moved.existsSync(), isTrue);
      expect(moved.path, p.join(handOffDir.path, 'photo.png'));
      expect(p.basename(moved.path), p.basename(source.path));
      expect(moved.readAsBytesSync(), <int>[9, 8, 7]);
    });

    test('returns a file that is already in the hand-off folder unchanged', () async {
      final File file = writeFile(handOffDir, 'kept.png');

      final File result = await inbox.handOff(file.path);

      expect(result.path, file.path);
      expect(file.existsSync(), isTrue);
    });
  });

  group('discard', () {
    test('does not start an unused hand-off lookup when the inbox owns the file', () async {
      final File file = writeFile(inboxDir, 'owned.png');
      int handOffLookups = 0;
      final SharedInbox isolated = SharedInbox(
        inboxDirectory: () async => inboxDir,
        handOffDirectory: () async {
          handOffLookups++;
          throw PlatformException(code: 'unavailable');
        },
      );

      await isolated.discard(file.path);

      expect(file.existsSync(), isFalse);
      expect(handOffLookups, 0);
    });
    test('deletes a file in the inbox', () async {
      final File file = writeFile(inboxDir, 'a.png');

      await inbox.discard(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('deletes a file in the hand-off folder', () async {
      final File file = writeFile(handOffDir, 'b.png');

      await inbox.discard(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('leaves a file outside both folders', () async {
      final Directory elsewhere = Directory(p.join(root.path, 'elsewhere'))..createSync();
      final File file = writeFile(elsewhere, 'c.png');

      await inbox.discard(file.path);

      expect(file.existsSync(), isTrue);
    });

    test('leaves the target of a symlink in the inbox', () async {
      final Directory elsewhere = Directory(p.join(root.path, 'elsewhere'))..createSync();
      final File target = writeFile(elsewhere, 'target.png');
      final String linkPath = p.join(inboxDir.path, 'link.png');
      await Link(linkPath).create(target.path);

      await inbox.discard(linkPath);

      expect(target.existsSync(), isTrue);
    });

    test('deletes a hand-off file even when the native inbox is unavailable', () async {
      final File file = writeFile(handOffDir, 'offline.png');
      final SharedInbox offline = SharedInbox(
        inboxDirectory: () => Future<Directory>.error(PlatformException(code: 'unavailable')),
        handOffDirectory: () async => handOffDir,
      );

      await offline.discard(file.path);

      expect(file.existsSync(), isFalse);
    });
  });

  group('sweep', () {
    test('an unavailable hand-off folder does not prevent sweeping the inbox', () async {
      final DateTime now = DateTime.now();
      final File file = writeFile(inboxDir, 'old_owned.png')
        ..setLastModifiedSync(now.subtract(const Duration(hours: 25)));
      final SharedInbox isolated = SharedInbox(
        inboxDirectory: () async => inboxDir,
        handOffDirectory: () async => throw PlatformException(code: 'unavailable'),
      );

      expect(await isolated.sweep(now: now), 1);
      expect(file.existsSync(), isFalse);
    });
    test('deletes files older than 24 hours in both folders and keeps recent ones', () async {
      final DateTime now = DateTime.now();
      final File oldInbox = writeFile(inboxDir, 'old_inbox.png')
        ..setLastModifiedSync(now.subtract(const Duration(hours: 25)));
      final File newInbox = writeFile(inboxDir, 'new_inbox.png')
        ..setLastModifiedSync(now.subtract(const Duration(hours: 1)));
      final File oldHandOff = writeFile(handOffDir, 'old_hand_off.png')
        ..setLastModifiedSync(now.subtract(const Duration(hours: 25)));
      final File newHandOff = writeFile(handOffDir, 'new_hand_off.png')
        ..setLastModifiedSync(now.subtract(const Duration(hours: 1)));

      final int deleted = await inbox.sweep(now: now);

      expect(deleted, 2);
      expect(oldInbox.existsSync(), isFalse);
      expect(oldHandOff.existsSync(), isFalse);
      expect(newInbox.existsSync(), isTrue);
      expect(newHandOff.existsSync(), isTrue);
    });

    test('does not throw when a folder is missing', () async {
      final SharedInbox missing = SharedInbox(
        inboxDirectory: () async => Directory(p.join(root.path, 'no_inbox')),
        handOffDirectory: () async => Directory(p.join(root.path, 'no_hand_off')),
      );

      expect(await missing.sweep(), 0);
    });

    test('sweeps the hand-off folder even when the native inbox is unavailable', () async {
      final DateTime now = DateTime.now();
      final File oldHandOff = writeFile(handOffDir, 'old_offline.png')
        ..setLastModifiedSync(now.subtract(const Duration(hours: 25)));
      final SharedInbox offline = SharedInbox(
        inboxDirectory: () => Future<Directory>.error(PlatformException(code: 'unavailable')),
        handOffDirectory: () async => handOffDir,
      );

      expect(await offline.sweep(now: now), 1);
      expect(oldHandOff.existsSync(), isFalse);
    });
  });

  test('newHandOffFile returns a new path in the hand-off folder', () async {
    final File first = await inbox.newHandOffFile('png');
    final File second = await inbox.newHandOffFile('png');

    expect(p.dirname(first.path), handOffDir.path);
    expect(first.path.endsWith('.png'), isTrue);
    expect(second.path, isNot(first.path));
  });
}
