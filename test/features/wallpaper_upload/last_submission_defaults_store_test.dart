import 'dart:io';

import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/last_submission_defaults_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('last details persist only category and tags and remain isolated by owner', () async {
    final directory = await Directory.systemTemp.createTemp('prism-last-details-');
    addTearDown(() => directory.delete(recursive: true));
    final json = DurableJsonStore('defaults_test', directory: directory);
    final store = LastSubmissionDefaultsStore(store: json);
    await store.save(
      'creator',
      const SubmissionMetadata(
        title: 'Private title',
        description: 'Private description',
        category: 'Nature',
        tags: ['forest'],
        requestId: 'request',
        requestText: 'Request text',
      ),
    );
    expect(await json.read('creator'), {
      'owner': 'creator',
      'category': 'Nature',
      'tags': ['forest'],
    });
    final restored = await LastSubmissionDefaultsStore(store: json).read('creator');
    expect(restored!.category, 'Nature');
    expect(restored.tags, ['forest']);
    expect(restored.title, '');
    expect(restored.description, '');
    expect(restored.requestId, '');
    expect(await store.read('another-creator'), isNull);
    await store.clearForUser('creator');
    expect(await store.read('creator'), isNull);
  });
}
