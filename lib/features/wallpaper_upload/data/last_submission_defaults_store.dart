import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';

class LastSubmissionDefaultsStore {
  LastSubmissionDefaultsStore({DurableJsonStore? store}) : _store = store ?? DurableJsonStore('upload_defaults');
  final DurableJsonStore _store;
  static Future<void> _writeTail = Future<void>.value();
  static final Map<String, int> _generations = <String, int>{};

  Future<SubmissionMetadata?> read(String owner) async {
    if (owner.isEmpty || owner == 'guest') return null;
    await _writeTail;
    final data = await _store.read(owner);
    if (data == null || data['owner'] != owner) return null;
    final category = data['category'];
    final tags = data['tags'];
    if (category is! String || !submissionCategories.contains(category) || tags is! List) return null;
    return SubmissionMetadata(
      category: category,
      tags: tags.whereType<String>().take(maxSubmissionTags).toList(growable: false),
    );
  }

  Future<void> save(String owner, SubmissionMetadata metadata) {
    if (owner.isEmpty || owner == 'guest') return Future.value();
    final generation = _generations[owner] ?? 0;
    return _serialize(() async {
      if ((_generations[owner] ?? 0) != generation) return;
      await _store.write(owner, <String, Object?>{
        'owner': owner,
        'category': metadata.category,
        'tags': metadata.tags,
      });
    });
  }

  Future<void> clearForUser(String owner) {
    _generations[owner] = (_generations[owner] ?? 0) + 1;
    return _serialize(() => _store.delete(owner));
  }

  Future<void> _serialize(Future<void> Function() action) {
    final result = _writeTail.then((_) => action());
    _writeTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
