import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallpaper_detail/data/repositories/wall_variant_repository_impl.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Answers `query` from canned `(data, docId)` rows and records the spec it was asked.
class _FakeFirestore extends Mock implements FirestoreClient {
  final List<({Map<String, dynamic> data, String docId})> rows = <({Map<String, dynamic> data, String docId})>[];
  FirestoreQuerySpec? spec;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    this.spec = spec;
    return <T>[for (final row in rows) map(row.data, row.docId)];
  }
}

/// A raw `walls` document as the server stores it. Rows are `(data, docId)` pairs.
Map<String, dynamic> _row({
  required String id,
  required int index,
  bool originalProtected = true,
  String wallpaperUrl = '',
  String groupId = 'doc0',
}) => <String, dynamic>{
  'id': id,
  'review': true,
  'originalProtected': originalProtected,
  'wallpaper_url': wallpaperUrl,
  'wallpaper_thumb': 'https://example.com/$id-thumb.jpg',
  'variantGroupId': groupId,
  'variantIndex': index,
  'by': 'Asha',
  'email': 'asha@example.com',
};

PrismWallpaper _asked({String? docId = 'doc0'}) => PrismWallpaper(
  core: const WallpaperCore(id: 'v0', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  firestoreDocumentId: docId,
  variantGroupId: 'doc0',
  variantIndex: 0,
);

void main() {
  late _FakeFirestore firestore;
  late WallVariantRepositoryImpl repository;

  setUp(() {
    firestore = _FakeFirestore();
    repository = WallVariantRepositoryImpl(firestore: () => firestore);
  });

  void addRow(String docId, Map<String, dynamic> data) => firestore.rows.add((data: data, docId: docId));

  group('WallVariantRepositoryImpl.load', () {
    test('returns members sorted by variantIndex even when rows arrive out of order', () async {
      addRow('doc2', _row(id: 'v2', index: 2));
      addRow('doc0', _row(id: 'v0', index: 0));
      addRow('doc1', _row(id: 'v1', index: 1));

      final VariantGroup? group = await repository.load(_asked());

      expect(group?.id, 'doc0');
      expect(group?.walls.map((w) => w.id), ['v0', 'v1', 'v2']);
      expect(group?.walls.map((w) => w.firestoreDocumentId), ['doc0', 'doc1', 'doc2']);
    });

    test('drops rows that are not original-protected or that carry a wallpaper url', () async {
      addRow('doc0', _row(id: 'v0', index: 0));
      addRow('doc1', _row(id: 'v1', index: 1, originalProtected: false));
      addRow('doc2', _row(id: 'v2', index: 2, wallpaperUrl: 'https://example.com/v2.jpg'));
      addRow('doc3', _row(id: 'v3', index: 3));

      final VariantGroup? group = await repository.load(_asked());

      expect(group?.walls.map((w) => w.id), ['v0', 'v3']);
    });

    test('returns null when fewer than 2 rows remain after the drops', () async {
      addRow('doc0', _row(id: 'v0', index: 0));
      addRow('doc1', _row(id: 'v1', index: 1, originalProtected: false));

      expect(await repository.load(_asked()), isNull);
    });

    test('returns null when the asked wall is not among the remaining rows', () async {
      addRow('doc1', _row(id: 'v1', index: 1));
      addRow('doc2', _row(id: 'v2', index: 2));

      expect(await repository.load(_asked()), isNull);
    });

    test('queries walls by variantGroupId and review with a limit of 5', () async {
      addRow('doc0', _row(id: 'v0', index: 0));
      addRow('doc1', _row(id: 'v1', index: 1));

      await repository.load(_asked());

      final FirestoreQuerySpec spec = firestore.spec!;
      expect(spec.collection, 'walls');
      expect(spec.limit, 5);
      expect(spec.filters.map((f) => (f.field, f.op, f.value)).toList(), [
        ('variantGroupId', FirestoreFilterOp.isEqualTo, 'doc0'),
        ('review', FirestoreFilterOp.isEqualTo, true),
      ]);
    });
  });
}
