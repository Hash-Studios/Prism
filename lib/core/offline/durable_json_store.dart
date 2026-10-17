import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DurableJsonStore {
  DurableJsonStore(String name, {Directory? directory, @visibleForTesting this.beforeReadContents})
    : _name = _validateName(name),
      _directoryOverride = directory;

  static const int maxRecords = 10000;
  static const int maxRecordBytes = 1024 * 1024;
  static const int maxStoreBytes = 64 * 1024 * 1024;

  final String _name;
  final Directory? _directoryOverride;

  @visibleForTesting
  final Future<void> Function(File file)? beforeReadContents;
  Future<void> _writeTail = Future<void>.value();

  Future<Map<String, Object?>?> read(String key) async {
    _validateKey(key);
    await _writeTail;
    final directory = await _directory();
    final file = File(path.join(directory.path, '${_recordId(key)}.json'));
    try {
      if (await FileSystemEntity.type(file.path, followLinks: false) != FileSystemEntityType.file ||
          await file.length() > maxRecordBytes) {
        return null;
      }
      await beforeReadContents?.call(file);
      return await _readRecord(file, key);
    } on FileSystemException {
      return null;
    }
  }

  Future<Map<String, Map<String, Object?>>> readAll() async {
    await _writeTail;
    final directory = await _directory();
    if (!await directory.exists()) return <String, Map<String, Object?>>{};
    final files = <File>[];
    var scanned = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (scanned++ >= maxRecords * 2) break;
      if (entity is File && path.extension(entity.path) == '.json' && files.length < maxRecords) {
        files.add(entity);
      }
    }
    files.sort((left, right) => path.basename(left.path).compareTo(path.basename(right.path)));
    final records = <String, Map<String, Object?>>{};
    var totalReadBytes = 0;
    for (final file in files) {
      try {
        final fileBytes = await file.length();
        if (fileBytes > maxRecordBytes || totalReadBytes + fileBytes > maxStoreBytes) continue;
        final contents = await file.readAsString();
        totalReadBytes += fileBytes;
        final decoded = jsonDecode(contents);
        if (decoded is! Map<String, dynamic> || decoded['key'] is! String || decoded['value'] is! Map) continue;
        final key = decoded['key'] as String;
        if (_recordId(key) != path.basenameWithoutExtension(file.path) || records.containsKey(key)) continue;
        records[key] = Map<String, Object?>.from(decoded['value'] as Map);
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return records;
  }

  Future<void> write(String key, Map<String, Object?> value) {
    _validateKey(key);
    final encoded = jsonEncode(<String, Object?>{'key': key, 'value': value});
    final encodedBytes = utf8.encode(encoded).length;
    if (encodedBytes > maxRecordBytes) {
      return Future<void>.error(const DurableJsonStoreLimitException('The JSON record is too large.'));
    }
    return _serialize(() async {
      final directory = await _directory();
      await directory.create(recursive: true);
      final target = File(path.join(directory.path, '${_recordId(key)}.json'));
      final stats = await _recordStats(directory);
      final targetExists = await target.exists();
      final targetBytes = targetExists ? await target.length() : 0;
      if (!targetExists && stats.count >= maxRecords) {
        throw const DurableJsonStoreLimitException('The JSON store has reached its record limit.');
      }
      if (stats.bytes - targetBytes + encodedBytes > maxStoreBytes) {
        throw const DurableJsonStoreLimitException('The JSON store has reached its byte limit.');
      }
      final temporary = File(path.join(directory.path, '.${_recordId(key)}.${_temporaryId++}.part'));
      try {
        await temporary.writeAsString(encoded, flush: true);
        await temporary.rename(target.path);
      } catch (_) {
        try {
          if (await temporary.exists()) await temporary.delete();
        } on FileSystemException catch (cleanupError) {
          if (cleanupError.path != temporary.path) rethrow;
        }
        rethrow;
      }
    });
  }

  Future<void> delete(String key) {
    _validateKey(key);
    return _serialize(() async {
      final directory = await _directory();
      final file = File(path.join(directory.path, '${_recordId(key)}.json'));
      if (await file.exists()) await file.delete();
    });
  }

  Future<void> clear() => _serialize(() async {
    final directory = await _directory();
    if (!await directory.exists()) return;
    var scanned = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (scanned++ >= maxRecords * 2) break;
      if (entity is File && (path.extension(entity.path) == '.json' || path.extension(entity.path) == '.part')) {
        await entity.delete();
      }
    }
  });

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, Object?>?> _readRecord(File file, String expectedKey) async {
    try {
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic> || decoded['key'] != expectedKey || decoded['value'] is! Map) return null;
      return Map<String, Object?>.from(decoded['value'] as Map);
    } on FormatException {
      return null;
    }
  }

  Future<({int count, int bytes})> _recordStats(Directory directory) async {
    var count = 0;
    var bytes = 0;
    var scanned = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (scanned++ >= maxRecords * 2) break;
      if (entity is File && path.extension(entity.path) == '.json') {
        count++;
        bytes += await entity.length();
      }
    }
    return (count: count, bytes: bytes);
  }

  Future<Directory> _directory() async =>
      _directoryOverride ??
      Directory(path.join((await getApplicationSupportDirectory()).path, 'prism', 'offline', _name));

  static String _recordId(String key) => sha256.convert(utf8.encode(key)).toString();

  static String _validateName(String name) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Use 1-64 letters, digits, underscores, or hyphens.');
    }
    return name;
  }

  static void _validateKey(String key) {
    if (key.isEmpty || utf8.encode(key).length > 4096) throw ArgumentError.value(key, 'key');
  }

  static int _temporaryId = 0;
}

class DurableJsonStoreLimitException implements Exception {
  const DurableJsonStoreLimitException(this.message);

  final String message;

  @override
  String toString() => 'DurableJsonStoreLimitException: $message';
}
