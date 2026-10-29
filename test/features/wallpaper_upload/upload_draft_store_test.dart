import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingRecordStore extends Fake implements DurableJsonStore {
  @override
  Future<Map<String, Object?>?> read(String key) async => null;

  @override
  Future<Map<String, Map<String, Object?>>> readAll() async => <String, Map<String, Object?>>{};

  @override
  Future<void> write(String key, Map<String, Object?> value) async => throw StateError('disk full');
}

void main() {
  late Directory root;
  late Directory recordsDirectory;
  late Directory filesDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('prism-upload-draft-test');
    recordsDirectory = Directory('${root.path}/records');
    filesDirectory = Directory('${root.path}/draft-files');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('the same selected image bytes have the same draft id across file paths', () async {
    final first = File('${root.path}/camera.png')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final second = await first.copy('${root.path}/gallery.png');

    expect(
      UploadDraftStore.idForBytes(await first.readAsBytes()),
      UploadDraftStore.idForBytes(await second.readAsBytes()),
    );
    expect(
      UploadDraftStore.idForBytes(<int>[4, 3, 2, 1]),
      isNot(UploadDraftStore.idForBytes(await first.readAsBytes())),
    );
  });

  test('owns a file and restores metadata after the store is reopened', () async {
    final File original = File('${root.path}/selected.png')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final UploadDraftStore firstRun = UploadDraftStore(
      store: DurableJsonStore('upload_test', directory: recordsDirectory),
      directory: filesDirectory,
    );
    final String draftId = UploadDraftStore.idForBytes(await original.readAsBytes());
    final UploadDraft saved = await firstRun.save(
      owner: 'account-a',
      draftId: draftId,
      selectedFile: original,
      metadata: const SubmissionMetadata(
        title: 'Aurora',
        category: 'Nature',
        tags: <String>['night'],
        requestId: 'r1',
        requestText: 'Northern lights',
      ),
    );
    await original.delete();

    final UploadDraftStore afterRestart = UploadDraftStore(
      store: DurableJsonStore('upload_test', directory: recordsDirectory),
      directory: filesDirectory,
    );
    final UploadDraft? restored = await afterRestart.read(owner: 'account-a', draftId: draftId);

    expect(restored, isNotNull);
    expect(restored!.file.path, saved.file.path);
    expect(await restored.file.readAsBytes(), <int>[1, 2, 3, 4]);
    expect(restored.metadata.title, 'Aurora');
    expect(restored.metadata.category, 'Nature');
    expect(restored.metadata.tags, <String>['night']);
    expect(restored.metadata.requestId, 'r1');
    expect(restored.metadata.requestText, 'Northern lights');
    expect(await afterRestart.read(owner: 'account-b', draftId: draftId), isNull);
  });

  test('creates a missing nested draft directory on first save', () async {
    final File original = File('${root.path}/selected.png')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final Directory nestedFiles = Directory('${root.path}/app-support/prism/offline/upload_drafts');
    final UploadDraftStore drafts = UploadDraftStore(
      store: DurableJsonStore('upload_test_nested', directory: recordsDirectory),
      directory: nestedFiles,
    );

    final UploadDraft saved = await drafts.save(
      owner: 'guest',
      draftId: 'draft-1',
      selectedFile: original,
      metadata: const SubmissionMetadata(title: 'First install'),
    );

    expect(await saved.file.exists(), isTrue);
    expect(await nestedFiles.exists(), isTrue);
  });

  test('rejects files above the per-draft byte limit before copying', () async {
    final File original = File('${root.path}/too-large.png');
    final RandomAccessFile handle = await original.open(mode: FileMode.writeOnly);
    await handle.setPosition(UploadDraftStore.maxDraftFileBytes);
    await handle.writeByte(1);
    await handle.close();
    final UploadDraftStore drafts = UploadDraftStore(
      store: DurableJsonStore('upload_test_limit', directory: recordsDirectory),
      directory: filesDirectory,
    );

    await expectLater(
      drafts.save(owner: 'guest', draftId: 'too-large', selectedFile: original, metadata: const SubmissionMetadata()),
      throwsA(isA<UploadDraftLimitException>()),
    );
    expect(await filesDirectory.exists(), isFalse);
  });

  test('removes abandoned temporary and unreferenced draft files during repair', () async {
    final File original = File('${root.path}/selected.png')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    await filesDirectory.create(recursive: true);
    final Directory files = Directory('${filesDirectory.path}/files')..createSync();
    final File partial = File('${files.path}/interrupted.part')..writeAsBytesSync(<int>[1]);
    final File orphan = File('${files.path}/orphan.image')..writeAsBytesSync(<int>[2]);
    final UploadDraftStore drafts = UploadDraftStore(
      store: DurableJsonStore('upload_test_repair', directory: recordsDirectory),
      directory: filesDirectory,
    );

    await drafts.save(owner: 'guest', draftId: 'draft-1', selectedFile: original, metadata: const SubmissionMetadata());

    expect(await partial.exists(), isFalse);
    expect(await orphan.exists(), isFalse);
  });

  test('clears only records and owned files for the requested user', () async {
    final File original = File('${root.path}/selected.png')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final DurableJsonStore records = DurableJsonStore('upload_test', directory: recordsDirectory);
    final UploadDraftStore drafts = UploadDraftStore(store: records, directory: filesDirectory);
    final String draftId = UploadDraftStore.idForBytes(await original.readAsBytes());
    final UploadDraft a = await drafts.save(
      owner: 'account-a',
      draftId: draftId,
      selectedFile: original,
      metadata: const SubmissionMetadata(title: 'A'),
    );
    final UploadDraft b = await drafts.save(
      owner: 'account-b',
      draftId: draftId,
      selectedFile: original,
      metadata: const SubmissionMetadata(title: 'B'),
    );

    await drafts.clearForUser('account-a');

    expect(await drafts.read(owner: 'account-a', draftId: draftId), isNull);
    expect(await drafts.read(owner: 'account-b', draftId: draftId), isNotNull);
    expect(await a.file.exists(), isFalse);
    expect(await b.file.exists(), isTrue);
  });

  test('finds the latest resumable draft only for the requested owner', () async {
    final File first = File('${root.path}/first.png')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final File second = File('${root.path}/second.png')..writeAsBytesSync(<int>[5, 6, 7, 8]);
    final UploadDraftStore drafts = UploadDraftStore(
      store: DurableJsonStore('upload_test_latest', directory: recordsDirectory),
      directory: filesDirectory,
    );
    await drafts.save(
      owner: 'account-a',
      draftId: 'first',
      selectedFile: first,
      metadata: const SubmissionMetadata(title: 'Old private draft'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await drafts.save(
      owner: 'account-a',
      draftId: 'second',
      selectedFile: second,
      metadata: const SubmissionMetadata(title: 'Latest draft'),
    );
    await drafts.save(
      owner: 'account-b',
      draftId: 'other-user',
      selectedFile: first,
      metadata: const SubmissionMetadata(title: 'Other account'),
    );

    final UploadDraft? latestA = await drafts.latestForOwner('account-a');
    final UploadDraft? latestB = await drafts.latestForOwner('account-b');

    expect(latestA?.draftId, 'second');
    expect(latestA?.metadata.title, 'Latest draft');
    expect(latestB?.draftId, 'other-user');
    expect(await drafts.latestForOwner(UploadDraftStore.guestOwner), isNull);
  });

  test('does not report a draft saved when its metadata write fails', () async {
    final File original = File('${root.path}/selected.png')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    final UploadDraftStore drafts = UploadDraftStore(store: _FailingRecordStore(), directory: filesDirectory);

    await expectLater(
      drafts.save(
        owner: 'guest',
        draftId: 'draft-1',
        selectedFile: original,
        metadata: const SubmissionMetadata(title: 'Local draft'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await filesDirectory.list(recursive: true).any((entity) => entity is File), isFalse);
  });
}
