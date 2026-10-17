import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;

/// One page of the coin ledger. [hasMore] is true when the page is full, so a next page may exist.
/// [cursor] is the last row read, including hidden zero rows. Pass it as `startAfterDocId` for the next page.
class CoinHistoryBatch {
  const CoinHistoryBatch({required this.items, required this.hasMore, this.cursor});

  final List<CoinTransactionEntry> items;
  final bool hasMore;
  final String? cursor;
}

/// Reads the signed-in user's coin ledger, newest first, one page at a time.
class CoinHistoryRepository {
  CoinHistoryRepository({FirestoreClient? client, String Function()? userId})
    : _client = client,
      _userId = userId ?? (() => app_state.prismUser.id);

  static const int pageSize = 40;

  final FirestoreClient? _client;
  final String Function() _userId;

  /// Reads a page after the ledger row [startAfterDocId]. A null cursor reads the newest page.
  /// Free outcomes (grace, pass, premium bypass) leave `delta: 0` receipts. They are hidden.
  Future<CoinHistoryBatch> fetchPage({String? startAfterDocId}) async {
    final List<CoinTransactionEntry> items = await (_client ?? firestoreClient).query<CoinTransactionEntry>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.coinTransactions,
        sourceTag: 'coin_history.page',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: _userId())],
        orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: 'createdAt', descending: true)],
        limit: pageSize,
        startAfterDocId: startAfterDocId,
      ),
      (data, docId) => CoinTransactionEntry.fromJson(data, fallbackId: docId),
    );
    return CoinHistoryBatch(
      items: items.where((CoinTransactionEntry e) => e.delta != 0).toList(growable: false),
      hasMore: items.length >= pageSize,
      cursor: items.isEmpty ? null : items.last.id,
    );
  }
}
