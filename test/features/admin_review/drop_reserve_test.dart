import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/biz/drop_reserve.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/data/review_batch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

Map<String, dynamic> _wall({String? origin, bool review = false, String? dropWeek}) => <String, dynamic>{
  'review': review,
  'category': 'Nature',
  'wallpaper_thumb': 'https://example.com/t.jpg',
  'origin': ?origin,
  'dropWeek': ?dropWeek,
};

void main() {
  group('canReserveForDrop', () {
    test('is true only for Studio walls that are not approved', () {
      expect(canReserveForDrop(FirestoreDocument('a', _wall(origin: 'studio'))), isTrue);
      expect(canReserveForDrop(FirestoreDocument('a', _wall())), isFalse);
      expect(canReserveForDrop(FirestoreDocument('a', _wall(origin: 'user'))), isFalse);
      expect(canReserveForDrop(FirestoreDocument('a', _wall(origin: 'studio', review: true))), isFalse);
    });
  });

  group('review batch', () {
    late FakeFirestoreClient client;
    late ReviewBatchBloc bloc;

    setUp(() {
      client = FakeFirestoreClient(
        docs: <String, Map<String, Map<String, dynamic>>>{
          FirebaseCollections.walls: <String, Map<String, dynamic>>{
            'studio': _wall(origin: 'studio'),
            'plain': _wall(),
            'planned': _wall(origin: 'studio', dropWeek: '2026-W42'),
          },
        },
      );
      client.onQuery = (_) => [
        for (final e in client.docs[FirebaseCollections.walls]!.entries)
          if (e.value['review'] == false) (id: e.key, data: Map<String, dynamic>.of(e.value)),
      ];
      bloc = ReviewBatchBloc(ReviewBatchRepository(client), AdminModerationRepository(client));
    });

    tearDown(() => bloc.close());

    Future<ReviewBatchState> loaded() {
      bloc.add(const ReviewBatchLoadRequested());
      return bloc.stream.firstWhere((s) => s.status == ReviewBatchStatus.loaded);
    }

    test('walls already in a Drop are left out of the queue and the pending count', () async {
      final state = await loaded();

      expect(state.walls.map((w) => w.id), <String>['studio', 'plain']);
      expect(state.totalPending, 2);
    });

    test('reserve flags a Studio wall, moves on, and undo clears the flag', () async {
      await loaded();

      bloc.add(const ReviewBatchSwipeReserved());
      final reserved = await bloc.stream.firstWhere((s) => s.currentIndex == 1);

      expect(client.docs[FirebaseCollections.walls]!['studio']!['dropReserved'], isTrue);
      expect(client.docs[FirebaseCollections.walls]!['studio']!['review'], isFalse);
      expect(client.writes.single.op, 'update');
      expect(reserved.totalPending, 1);
      expect(reserved.canUndo, isTrue);

      bloc.add(const ReviewBatchUndoRequested());
      final undone = await bloc.stream.firstWhere((s) => s.undoCount == 1);

      expect(client.docs[FirebaseCollections.walls]!['studio']!['dropReserved'], isFalse);
      expect(undone.currentIndex, 0);
    });

    test('reserve does nothing for a wall that is not a Studio wall', () async {
      await loaded();
      bloc.add(const ReviewBatchSwipeSkipped());
      await bloc.stream.firstWhere((s) => s.currentIndex == 1);

      bloc.add(const ReviewBatchSwipeReserved());
      await Future<void>.delayed(Duration.zero);

      expect(client.writes, isEmpty);
      expect(bloc.state.currentIndex, 1);
    });
  });
}
