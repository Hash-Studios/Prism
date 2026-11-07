import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where shared images wait. Native code fills the inbox (`prism/shared_inbox`); a picked action moves the file to
/// the hand-off folder, which the next flow owns. Both folders lose files older than [maxAge].
class SharedInbox {
  SharedInbox({
    MethodChannel channel = const MethodChannel('prism/shared_inbox'),
    Future<Directory> Function()? inboxDirectory,
    Future<Directory> Function()? handOffDirectory,
  }) : _channel = channel,
       _inboxDirectory = inboxDirectory,
       _handOffDirectory = handOffDirectory;

  static const Duration maxAge = Duration(hours: 24);

  final MethodChannel _channel;
  final Future<Directory> Function()? _inboxDirectory;
  final Future<Directory> Function()? _handOffDirectory;

  Future<Directory> inboxDirectory() async =>
      _inboxDirectory?.call() ?? Directory((await _channel.invokeMethod<String>('directory'))!);

  Future<Directory> handOffDirectory() async =>
      _handOffDirectory?.call() ?? Directory(p.join((await getTemporaryDirectory()).path, 'share_in'));

  /// The path of the image native code stored for [id]. Throws a [PlatformException] when it is missing or unreadable.
  Future<String> take(String id) async {
    final String? path = await _channel.invokeMethod<String>('take', id);
    if (path == null || path.isEmpty) throw PlatformException(code: 'missing');
    return path;
  }

  /// A new file in the hand-off folder for an image that Prism downloads itself.
  Future<File> newHandOffFile(String extension) async {
    final Directory folder = await handOffDirectory();
    await folder.create(recursive: true);
    final Random random = Random.secure();
    final String name = List<String>.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return File(p.join(folder.path, '$name.$extension'));
  }

  /// Moves [path] to the hand-off folder for the flow the user picked, and returns the new file.
  Future<File> handOff(String path) async {
    final Directory folder = await handOffDirectory();
    if (await _isInside(path, folder)) return File(path);
    await folder.create(recursive: true);
    final File target = File(p.join(folder.path, p.basename(path)));
    try {
      return await File(path).rename(target.path);
    } on FileSystemException {
      // The App Group container and the temp folder can be on different volumes.
      final File copy = await File(path).copy(target.path);
      await discard(path);
      return copy;
    }
  }

  /// Deletes [path] when it is in one of the share folders. Any other path stays.
  Future<void> discard(String path) async {
    for (final Directory folder in <Directory>[await inboxDirectory(), await handOffDirectory()]) {
      if (await _isInside(path, folder)) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Already gone.
        }
        return;
      }
    }
  }

  /// Deletes files older than [maxAge] in both folders. Returns how many it deleted.
  Future<int> sweep({DateTime? now}) async {
    final DateTime cutoff = (now ?? DateTime.now()).subtract(maxAge);
    int deleted = 0;
    for (final Directory folder in <Directory>[await inboxDirectory(), await handOffDirectory()]) {
      if (!await folder.exists()) continue;
      await for (final FileSystemEntity entity in folder.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
            deleted++;
          }
        } on FileSystemException {
          // Deleted by another sweep.
        }
      }
    }
    return deleted;
  }

  Future<bool> _isInside(String path, Directory folder) async {
    if (!await folder.exists()) return false;
    final String root = await folder.resolveSymbolicLinks();
    final String file = p.normalize(p.absolute(path));
    if (await FileSystemEntity.type(file, followLinks: false) != FileSystemEntityType.file) return false;
    return p.isWithin(root, await File(file).resolveSymbolicLinks());
  }
}
