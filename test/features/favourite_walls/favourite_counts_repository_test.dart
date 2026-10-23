import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/favourite_walls/data/repositories/favourite_counts_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Firestore extends Mock implements FirestoreClient {
  final batches = <List<String>>[];
  final docs = <String, Map<String, dynamic>>{};
  bool fail = false;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    expect(spec.collection, 'wallpaper_stats');
    expect(spec.sourceTag, 'favourite_counts.grid');
    expect(spec.cachePolicy, FirestoreCachePolicy.serverOnly);
    expect(spec.filters.single.field, firestoreDocumentIdField);
    expect(spec.filters.single.op, FirestoreFilterOp.whereIn);
    final ids = spec.filters.single.value! as List<String>;
    batches.add(ids);
    if (fail) throw StateError('offline');
    return [
      for (final id in ids)
        if (docs.containsKey(id)) map(docs[id]!, id),
    ];
  }
}

void main() {
  test('normalizes, dedupes, validates IDs and chunks at 30', () async {
    final firestore = _Firestore();
    final repository = FavouriteCountsRepositoryImpl(firestore);
    final counts = await repository.fetch({for (var i = 0; i < 65; i++) 'wall-$i', ' WALL-0 ', 'bad/id', ''});
    expect(firestore.batches.map((batch) => batch.length), [30, 30, 5]);
    expect(counts, hasLength(65));
    expect(counts.values, everyElement(0));
    expect(firestore.batches.first.first, 'WALL-0');
  });

  test('missing and malformed counts are zero, never negative', () async {
    final firestore = _Firestore()
      ..docs.addAll({
        'A': {'favs': 42},
        'B': {'favs': -5},
        'C': {'favs': '12'},
        'D': {'favs': 'bad'},
        'E': {'favs': double.nan},
      });
    final counts = await FavouriteCountsRepositoryImpl(firestore).fetch({'A', 'B', 'C', 'D', 'E', 'MISSING'});
    expect(counts, {'A': 42, 'B': 0, 'C': 12, 'D': 0, 'E': 0, 'MISSING': 0});
  });

  test('read failure throws instead of manufacturing zero', () async {
    final firestore = _Firestore()..fail = true;
    await expectLater(FavouriteCountsRepositoryImpl(firestore).fetch({'A'}), throwsStateError);
  });
}
