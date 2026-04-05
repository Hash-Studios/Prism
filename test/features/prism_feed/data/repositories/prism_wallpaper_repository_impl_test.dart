import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrismWallpaperRepositoryImpl', () {
    test('waits for blocked creators and refills filtered pages without skipping visible rows', () async {
      final firestore = _FakeFirestoreClient(_buildWallDocs(count: 30));
      final cache = _FakeFeedCacheLocalDataSource();
      final blocks = _FakeUserBlockRepository.pending();
      final repo = PrismWallpaperRepositoryImpl(firestore, cache, blocks);

      final Future<Result<List<PrismWallpaper>>> pending = repo.fetchFeed(refresh: true);
      await Future<void>.delayed(Duration.zero);

      expect(firestore.queryCalls, 0);

      blocks.completeInitial(<String>{'creator1@example.com', 'creator2@example.com', 'creator3@example.com'});

      final firstPage = await pending;
      expect(firstPage.isSuccess, isTrue);
      expect(firstPage.data, hasLength(24));
      expect(firstPage.data!.first.core.id, 'wall-4');
      expect(firstPage.data!.last.core.id, 'wall-27');
      expect(repo.hasMore, isTrue);
      expect(firestore.queryCalls, 2);

      final secondPage = await repo.fetchFeed(refresh: false);
      expect(secondPage.isSuccess, isTrue);
      expect(secondPage.data!.map((wall) => wall.core.id).toList(growable: false), <String>[
        'wall-28',
        'wall-29',
        'wall-30',
      ]);
      expect(repo.hasMore, isFalse);
    });
  });
}

class _FakeFirestoreClient implements FirestoreClient {
  _FakeFirestoreClient(this._docs);

  final List<({String docId, Map<String, dynamic> data})> _docs;
  int queryCalls = 0;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    queryCalls += 1;
    final int startIndex;
    if (spec.startAfterDocId == null) {
      startIndex = 0;
    } else {
      final int lastIndex = _docs.indexWhere((doc) => doc.docId == spec.startAfterDocId);
      startIndex = lastIndex < 0 ? 0 : lastIndex + 1;
    }
    final List<({String docId, Map<String, dynamic> data})> slice = _docs
        .skip(startIndex)
        .take(spec.limit ?? _docs.length)
        .toList(growable: false);
    return slice.map((doc) => map(doc.data, doc.docId)).toList(growable: false);
  }

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> addDoc(String collection, Map<String, dynamic> data, {required String sourceTag}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDoc(String collection, String id, {required String sourceTag}) {
    throw UnimplementedError();
  }

  @override
  Future<void> runBatch(Future<void> Function(FirestoreBatch batch) action, {required String sourceTag}) {
    throw UnimplementedError();
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) {
    throw UnimplementedError();
  }

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) {
    throw UnimplementedError();
  }
}

class _FakeFeedCacheLocalDataSource extends FeedCacheLocalDataSource {
  FeedSnapshot? _snapshot;

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async => _snapshot;

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {
    _snapshot = FeedSnapshot(payload: payload, cachedAtUtc: DateTime.now().toUtc(), ttlHours: ttlHours);
  }
}

class _FakeUserBlockRepository implements UserBlockRepository {
  _FakeUserBlockRepository.pending();

  final StreamController<Set<String>> _controller = StreamController<Set<String>>.broadcast();
  final Completer<Set<String>> _initialLoad = Completer<Set<String>>();

  Set<String> _cached = <String>{};
  bool _hasLoaded = false;

  void completeInitial(Set<String> blocked) {
    _cached = blocked;
    _hasLoaded = true;
    if (!_initialLoad.isCompleted) {
      _initialLoad.complete(blocked);
    }
    _controller.add(blocked);
  }

  @override
  Set<String> get cachedBlockedCreatorEmails => _cached;

  @override
  Future<Result<void>> blockUser({required String targetUserId}) async => Result.success(null);

  @override
  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList() async =>
      Result.success(const <BlockedUserListRow>[]);

  @override
  Future<Set<String>> getBlockedCreatorEmails({bool waitForInitialLoad = false}) async {
    if (waitForInitialLoad && !_hasLoaded) {
      return _initialLoad.future;
    }
    return _cached;
  }

  @override
  bool get hasLoadedBlockedCreatorEmails => _hasLoaded;

  @override
  Future<Result<void>> unblockUser({required String targetUserId}) async => Result.success(null);

  @override
  Stream<Set<String>> watchBlockedCreatorEmails() => _controller.stream;
}

List<({String docId, Map<String, dynamic> data})> _buildWallDocs({required int count}) {
  return List<({String docId, Map<String, dynamic> data})>.generate(count, (index) {
    final int n = index + 1;
    return (
      docId: 'doc-$n',
      data: <String, dynamic>{
        'id': 'wall-$n',
        'wallpaper_url': 'https://example.com/full/$n.jpg',
        'wallpaper_thumb': 'https://example.com/thumb/$n.jpg',
        'wallpaper_provider': 'prism',
        'resolution': '1440x3200',
        'createdAt': DateTime.utc(2026, 1, 1).subtract(Duration(minutes: index)).toIso8601String(),
        'by': 'Creator $n',
        'email': 'creator$n@example.com',
        'review': true,
      },
    );
  });
}
