import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class UploadDraftStore {
  static const String guestOwner = 'guest';
  static const int maxDraftFileBytes = 15 * 1024 * 1024;
  static const int maxDraftCount = 20;
  static const int maxDraftsPerOwner = 10;
  static const int maxDraftBytes = 150 * 1024 * 1024;
  static const int maxDraftBytesPerOwner = 60 * 1024 * 1024;

  UploadDraftStore({DurableJsonStore? store, Directory? directory})
    : _store = store ?? DurableJsonStore('upload_drafts'),
      _directoryOverride = directory;

  final DurableJsonStore _store;
  final Directory? _directoryOverride;
  static Future<void> _writeTail = Future<void>.value();
  static final Map<String, int> _ownerGenerations = <String, int>{};
  int _fileSequence = 0;

  static String idForBytes(List<int> bytes) => sha256.convert(bytes).toString();

  Future<UploadDraft> save({
    required String owner,
    required String draftId,
    required File selectedFile,
    required SubmissionMetadata metadata,
  }) {
    final int generation = _ownerGenerations[owner] ?? 0;
    return _serialize(
      () =>
          _save(owner: owner, draftId: draftId, selectedFile: selectedFile, metadata: metadata, generation: generation),
    );
  }

  Future<UploadDraft?> read({required String owner, required String draftId}) async {
    if (owner.isEmpty || draftId.isEmpty) return null;
    return _serialize(() async {
      await _repairFiles();
      final Map<String, Object?>? value = await _store.read(_key(owner, draftId));
      if (value == null || value['owner'] != owner || value['draftId'] != draftId) return null;
      final Object? relativeFile = value['file'];
      if (relativeFile is! String) return null;
      final File? file = await _fileFor(relativeFile);
      if (file == null || !await file.exists() || await file.length() <= 0) return null;
      return UploadDraft(owner: owner, draftId: draftId, file: file, metadata: _metadataFrom(value['metadata']));
    });
  }

  Future<UploadDraft?> latestForOwner(String owner) async {
    if (owner.isEmpty) return null;
    return _serialize(() async {
      await _repairFiles(owner: owner);
      final Map<String, Map<String, Object?>> records = await _store.readAll();
      final String prefix = 'draft/${Uri.encodeComponent(owner)}/';
      final List<MapEntry<String, Map<String, Object?>>> owned = records.entries
          .where(
            (entry) =>
                entry.key.startsWith(prefix) && entry.value['owner'] == owner && entry.value['draftId'] is String,
          )
          .toList(growable: false);
      owned.sort((a, b) => (b.value['savedAtUtc'] as String? ?? '').compareTo(a.value['savedAtUtc'] as String? ?? ''));
      for (final entry in owned) {
        final String draftId = entry.value['draftId']! as String;
        final Object? relativeFile = entry.value['file'];
        if (relativeFile is! String) continue;
        final File? file = await _fileFor(relativeFile);
        if (file == null || !await file.exists()) continue;
        return UploadDraft(
          owner: owner,
          draftId: draftId,
          file: file,
          metadata: _metadataFrom(entry.value['metadata']),
        );
      }
      return null;
    });
  }

  Future<void> discard({required String owner, required String draftId}) => _serialize(() async {
    final String key = _key(owner, draftId);
    final Map<String, Object?>? value = await _store.read(key);
    if (value == null || value['owner'] != owner) return;
    final Object? relative = value['file'];
    final File? file = relative is String ? await _fileFor(relative) : null;
    await _store.delete(key);
    if (file != null && await file.exists()) await file.delete();
  });

  Future<void> clearForUser(String userId) {
    if (userId.isEmpty) return Future<void>.value();
    cancelPendingWritesForUser(userId);
    return _serialize(() async {
      final String prefix = 'draft/${Uri.encodeComponent(userId)}/';
      final Map<String, Map<String, Object?>> records = await _store.readAll();
      for (final MapEntry<String, Map<String, Object?>> entry in records.entries) {
        if (!entry.key.startsWith(prefix) || entry.value['owner'] != userId) continue;
        final Object? relative = entry.value['file'];
        final File? file = relative is String ? await _fileFor(relative) : null;
        await _store.delete(entry.key);
        if (file != null && await file.exists()) await file.delete();
      }
    });
  }

  void cancelPendingWritesForUser(String userId) {
    if (userId.isEmpty) return;
    _ownerGenerations[userId] = (_ownerGenerations[userId] ?? 0) + 1;
  }

  Future<UploadDraft> _save({
    required String owner,
    required String draftId,
    required File selectedFile,
    required SubmissionMetadata metadata,
    required int generation,
  }) async {
    if (owner.isEmpty || draftId.isEmpty) throw ArgumentError('An upload draft needs an owner and id.');
    if (!await selectedFile.exists() || await selectedFile.length() <= 0) {
      throw const FileSystemException('The selected upload file is missing or empty.');
    }
    final int selectedLength = await selectedFile.length();
    if (selectedLength > maxDraftFileBytes) {
      throw const UploadDraftLimitException('The selected file is larger than the upload draft limit.');
    }
    final ({int count, int bytes, int ownerCount, int ownerBytes}) usage = await _repairFiles(owner: owner);
    final String key = _key(owner, draftId);
    _checkGeneration(owner, generation);
    final Map<String, Object?>? previous = await _store.read(key);
    final Object? previousRelative = previous?['file'];
    final File? previousFile = previousRelative is String ? await _fileFor(previousRelative) : null;
    if (previousFile != null &&
        await previousFile.exists() &&
        path.normalize(previousFile.absolute.path) == path.normalize(selectedFile.absolute.path)) {
      await _store.write(key, _recordValue(owner, draftId, previousRelative! as String, metadata));
      return UploadDraft(owner: owner, draftId: draftId, file: previousFile, metadata: metadata);
    }
    final int previousLength = previousFile != null && await previousFile.exists() ? await previousFile.length() : 0;
    final bool addingNew = previous == null;
    final int nextTotal = usage.bytes - previousLength + selectedLength;
    final int nextOwnerTotal = usage.ownerBytes - previousLength + selectedLength;
    if ((addingNew && (usage.count >= maxDraftCount || usage.ownerCount >= maxDraftsPerOwner)) ||
        nextTotal > maxDraftBytes ||
        nextOwnerTotal > maxDraftBytesPerOwner) {
      throw const UploadDraftLimitException(
        'The local upload draft limit is full. Discard a draft before saving another.',
      );
    }
    final Directory root = await _directory();
    final Directory files = Directory(path.join(root.path, 'files'));
    await files.create(recursive: true);
    final String stem = sha256.convert(utf8.encode(key)).toString();
    final String extension = path.extension(selectedFile.path);
    final String suffix = '${DateTime.now().microsecondsSinceEpoch}-${_fileSequence++}';
    final File destination = File(path.join(files.path, '$stem-$suffix${extension.isEmpty ? '.image' : extension}'));
    final File temporary = File('${destination.path}.part');
    try {
      final RandomAccessFile input = await selectedFile.open();
      final RandomAccessFile output = await temporary.open(mode: FileMode.writeOnly);
      try {
        while (true) {
          final List<int> chunk = await input.read(64 * 1024);
          if (chunk.isEmpty) break;
          await output.writeFrom(chunk);
        }
        await output.flush();
      } finally {
        await input.close();
        await output.close();
      }
      if (await temporary.length() != selectedLength) {
        throw const FileSystemException('The selected upload file changed while it was being copied.');
      }
      await temporary.rename(destination.path);
      _checkGeneration(owner, generation);
      final String relativeFile = path.relative(destination.path, from: root.path);
      await _store.write(key, _recordValue(owner, draftId, relativeFile, metadata));
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
    if (previousFile != null && previousFile.path != destination.path && await previousFile.exists()) {
      await previousFile.delete();
    }
    return UploadDraft(owner: owner, draftId: draftId, file: destination, metadata: metadata);
  }

  Future<({int count, int bytes, int ownerCount, int ownerBytes})> _repairFiles({String? owner}) async {
    final Directory root = await _directory();
    final Directory files = Directory(path.join(root.path, 'files'));
    await files.create(recursive: true);
    final Map<String, Map<String, Object?>> records = await _store.readAll();
    final Set<String> referencedPaths = <String>{};
    var count = 0;
    var bytes = 0;
    var ownerCount = 0;
    var ownerBytes = 0;
    for (final MapEntry<String, Map<String, Object?>> entry in records.entries) {
      final Map<String, Object?> record = entry.value;
      final Object? rawFile = record['file'];
      final File? file = rawFile is String ? await _fileFor(rawFile) : null;
      final bool valid =
          record['owner'] is String &&
          record['draftId'] is String &&
          file != null &&
          await file.exists() &&
          await file.length() > 0 &&
          await file.length() <= maxDraftFileBytes;
      if (!valid) {
        await _store.delete(entry.key);
        if (file != null && await file.exists()) await file.delete();
        continue;
      }
      referencedPaths.add(path.normalize(file.path));
      final int fileBytes = await file.length();
      count++;
      bytes += fileBytes;
      if (record['owner'] == owner) {
        ownerCount++;
        ownerBytes += fileBytes;
      }
    }
    await for (final FileSystemEntity entity in files.list(followLinks: false)) {
      if (entity is! File) continue;
      final String normalized = path.normalize(entity.path);
      if (path.extension(entity.path) == '.part' || !referencedPaths.contains(normalized)) {
        await entity.delete();
      }
    }
    return (count: count, bytes: bytes, ownerCount: ownerCount, ownerBytes: ownerBytes);
  }

  Map<String, Object?> _recordValue(String owner, String draftId, String file, SubmissionMetadata metadata) =>
      <String, Object?>{
        'owner': owner,
        'draftId': draftId,
        'file': file,
        'metadata': <String, Object?>{
          'title': metadata.title,
          'category': metadata.category,
          'tags': metadata.tags,
          'requestId': metadata.requestId,
          'requestText': metadata.requestText,
        },
        'savedAtUtc': DateTime.now().toUtc().toIso8601String(),
      };

  Future<File?> _fileFor(String relativeFile) async {
    if (path.isAbsolute(relativeFile)) return null;
    final String normalized = path.normalize(relativeFile);
    if (!normalized.startsWith('files${path.separator}') || path.split(normalized).length != 2) return null;
    final Directory root = await _directory();
    if (!await root.exists()) return null;
    final File file = File(path.join(root.path, normalized));
    final String canonicalRoot = await root.resolveSymbolicLinks();
    final String canonicalFile;
    try {
      canonicalFile = await file.resolveSymbolicLinks();
    } on FileSystemException {
      return null;
    }
    if (!canonicalFile.startsWith('$canonicalRoot${path.separator}')) return null;
    return file;
  }

  Future<Directory> _directory() async =>
      _directoryOverride ??
      Directory(path.join((await getApplicationSupportDirectory()).path, 'prism', 'offline', 'upload_drafts'));

  SubmissionMetadata _metadataFrom(Object? raw) {
    if (raw is! Map) return const SubmissionMetadata();
    final Object? rawTags = raw['tags'];
    return SubmissionMetadata(
      title: raw['title'] is String ? raw['title'] as String : '',
      category: raw['category'] is String ? raw['category'] as String : defaultSubmissionCategory,
      tags: rawTags is List ? rawTags.whereType<String>().toList(growable: false) : const <String>[],
      requestId: raw['requestId'] is String ? raw['requestId'] as String : '',
      requestText: raw['requestText'] is String ? raw['requestText'] as String : '',
    );
  }

  static String _key(String owner, String draftId) =>
      'draft/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(draftId)}';

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final Future<T> result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static void _checkGeneration(String owner, int generation) {
    if ((_ownerGenerations[owner] ?? 0) != generation) {
      throw const UploadDraftSupersededException('The upload draft owner changed before this save completed.');
    }
  }
}

class UploadDraft {
  const UploadDraft({required this.owner, required this.draftId, required this.file, required this.metadata});

  final String owner;
  final String draftId;
  final File file;
  final SubmissionMetadata metadata;
}

class UploadDraftLimitException implements Exception {
  const UploadDraftLimitException(this.message);

  final String message;

  @override
  String toString() => 'UploadDraftLimitException: $message';
}

class UploadDraftSupersededException implements Exception {
  const UploadDraftSupersededException(this.message);

  final String message;
}
