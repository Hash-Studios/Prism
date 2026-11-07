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
        handOffDirectory: () {
          handOffLookups++;
          return Future<Directory>.error(PlatformException(code: 'unavailable'));
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

  group('takePendingLink', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel channel = MethodChannel('test/pending_link');
    String? stored;

    setUp(() {
      stored = 'prism://share-in?text=https%3A%2F%2Fexample.com%2F';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        final String? link = stored;
        stored = null;
        return call.method == 'takePendingLink' ? link : null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('returns the pending share once', () async {
      final SharedInbox pending = SharedInbox(channel: channel);
      expect((await pending.takePendingLink()).toString(), 'prism://share-in?text=https%3A%2F%2Fexample.com%2F');
      expect(await pending.takePendingLink(), isNull);
    });

    test('drops the pending share when it is the share that just arrived', () async {
      final SharedInbox pending = SharedInbox(channel: channel);
      expect(await pending.takePendingLink(arriving: Uri.parse('prism://share-in?text=https://example.com/')), isNull);
      expect(stored, isNull, reason: 'the pending share is consumed either way');
    });

    test('returns a different pending share even when another share arrives', () async {
      final SharedInbox pending = SharedInbox(channel: channel);
      final Uri? link = await pending.takePendingLink(
        arriving: Uri.parse('prism://share-in?text=https://other.example/'),
      );
      expect(link?.queryParameters['text'], 'https://example.com/');
    });

    test('does not dispatch non-share or malformed pending links', () async {
      for (final String link in <String>[
        'prism://settings',
        'https://example.com/share-in?text=x',
        'prism://share-in?text=',
        'prism://share-in?id=missing',
        'prism://share-in?text=%FF',
        'prism://share-in?text=x&text=y',
        'prism://other.example/share-in?text=x',
        'prism://user@share-in?text=x',
        'prism://share-in:42?text=x',
      ]) {
        stored = link;
        expect(await SharedInbox(channel: channel).takePendingLink(), isNull, reason: link);
      }
    });

    test('same text from a new share is not mistaken for the arriving delivery', () async {
      stored = 'prism://share-in?text=x#123e4567-e89b-12d3-a456-426614174000';
      expect(
        await SharedInbox(
          channel: channel,
        ).takePendingLink(arriving: Uri.parse('prism://share-in?text=x#123e4567-e89b-12d3-a456-426614174001')),
        isNotNull,
      );
    });
  });

  test('pending and system deliveries are claimed once in either order, even after navigation', () async {
    for (final bool pendingFirst in <bool>[true, false]) {
      final SharedInbox delivery = SharedInbox();
      final Uri pending = Uri.parse(
        'prism://share-in?text=https%3A%2F%2Fprismwalls.com%2Fl%2Fa'
        '#123e4567-e89b-12d3-a456-426614174000',
      );
      final Uri system = pending.replace(host: '', path: '/share-in');
      expect(delivery.claimLink(pendingFirst ? pending : system), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(delivery.claimLink(pendingFirst ? system : pending), isFalse);
      expect(delivery.claimLink(pending.replace(fragment: '123e4567-e89b-12d3-a456-426614174001')), isTrue);
    }
  });

  test('a duplicate image never claims a second owner, while untagged external text may be shared again', () {
    final SharedInbox delivery = SharedInbox();
    final Uri image = Uri.parse('prism://share-in?id=123e4567-e89b-12d3-a456-426614174000');
    expect(delivery.claimLink(image), isTrue);
    expect(delivery.claimLink(image.replace(host: '', path: '/share-in')), isFalse);
    final Uri external = Uri.parse('prism://share-in?text=x');
    expect(delivery.claimLink(external), isTrue);
    expect(delivery.claimLink(external), isTrue);
    expect(delivery.claimLink(Uri.parse('prism://settings')), isFalse);
  });
}
