import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';

/// In-memory [FeedCacheLocalDataSource]: keeps the last snapshot per source and scope.
class FakeFeedCacheLocalDataSource extends FeedCacheLocalDataSource {
  final Map<String, FeedSnapshot> snapshots = <String, FeedSnapshot>{};

  @override
  Future<FeedSnapshot?> read({required String source, required String scope}) async => snapshots['$source/$scope'];

  @override
  Future<void> write({
    required String source,
    required String scope,
    required Object? payload,
    required int ttlHours,
  }) async {
    snapshots['$source/$scope'] = FeedSnapshot(
      payload: payload,
      cachedAtUtc: DateTime.now().toUtc(),
      ttlHours: ttlHours,
    );
  }
}
