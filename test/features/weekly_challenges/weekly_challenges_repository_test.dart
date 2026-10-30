import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/weekly_challenges/biz/challenge_admission_tracker.dart';
import 'package:Prism/features/weekly_challenges/data/weekly_challenges_repository_impl.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/in_memory_local_store.dart';

Map<String, Object?> row(String id, {String creator = 'creator'}) => {
  'id': id,
  'wallId': id,
  'wallLogicalId': 'logical-$id',
  'creatorUid': creator,
  'creatorName': 'Maya',
  'thumbUrl': '',
  'title': 'Ocean',
  'voteCount': 2,
  'approvedAtMs': 1,
  'voted': false,
  'mine': false,
};
Map<String, Object?> challengeMap({Object? winner}) => {
  'id': '2026-10-26',
  'theme': 'Quiet oceans',
  'state': 'open',
  'opensAtMs': 1,
  'closesAtMs': 4102444800000,
  'winner': winner,
  'reservedDate': null,
  'noWinner': false,
};
void main() {
  test('uses public server-only wall reads, drops missing and blocked entries and winners', () async {
    final blocks = FakeUserBlockRepository.pending()..completeInitial({'blocked'});
    final firestore = FakeFirestoreClient(
      onQuery: (spec) {
        final id = spec.filters.first.value;
        if (id == 'missing') return [];
        return [
          (
            id: id! as String,
            data: <String, dynamic>{
              'id': id == 'recreated' ? 'replacement' : 'logical-$id',
              'review': true,
              'creatorUid': 'creator',
              'wallpaper_url': 'https://image.test/$id',
              'wallpaper_thumb': '',
              'by': 'Maya',
            },
          ),
        ];
      },
    );
    final calls = <String>[];
    final repo = WeeklyChallengesRepositoryImpl.withCaller(
      WallRemixRepository(firestore, blocks),
      ChallengeAdmissionTracker(InMemoryLocalStore()),
      (name, args) async {
        calls.add(name);
        expect(args, {'challengeId': '2026-10-26', 'sort': 'new'});
        return {
          'challenge': challengeMap(winner: row('missing')),
          'entries': [row('wall'), row('missing'), row('recreated'), row('blocked-wall', creator: 'blocked')],
          'myEntryCount': 2,
          'myAdmittedWallIds': <String>[],
        };
      },
    );
    final detail = await repo.get('2026-10-26', ChallengeSort.newest);
    expect(detail.entries.map((entry) => entry.id), ['wall']);
    expect(detail.entries.single.wall!.firestoreDocumentId, 'wall');
    expect(detail.challenge.winner, isNull);
    expect(detail.myEntryCount, 2);
    expect(calls, ['getWeeklyChallenge']);
    expect(firestore.querySpecs.every((spec) => spec.cachePolicy == FirestoreCachePolicy.serverOnly), isTrue);
    expect(firestore.querySpecs.every((spec) => spec.sourceTag.isNotEmpty), isTrue);
  });
  test('unknown block state hides entries and winners until the block list loads', () async {
    final blocks = FakeUserBlockRepository.pending()..timeOutInitialLoad();
    final firestore = FakeFirestoreClient(
      onQuery: (spec) => [
        (
          id: 'wall',
          data: <String, dynamic>{
            'id': 'logical-wall',
            'review': true,
            'creatorUid': 'creator',
            'wallpaper_url': 'https://image.test/wall',
            'wallpaper_thumb': '',
            'by': 'Maya',
          },
        ),
      ],
    );
    final repo = WeeklyChallengesRepositoryImpl.withCaller(
      WallRemixRepository(firestore, blocks),
      ChallengeAdmissionTracker(InMemoryLocalStore()),
      (name, args) async => name == 'listWeeklyChallenges'
          ? {
              'challenges': [challengeMap(winner: row('wall'))],
            }
          : {
              'challenge': challengeMap(winner: row('wall')),
              'entries': [row('wall')],
              'myEntryCount': 0,
            },
    );
    final hidden = await repo.get('2026-10-26', ChallengeSort.top);
    expect(hidden.entries, isEmpty);
    expect(hidden.challenge.winner, isNull);
    expect((await repo.list(past: true)).single.winner, isNull);
    expect(firestore.querySpecs, isEmpty);
    blocks.completeInitial({});
    final visible = await repo.get('2026-10-26', ChallengeSort.top);
    expect(visible.entries.single.id, 'wall');
    expect(visible.challenge.winner!.id, 'wall');
    expect((await repo.list(past: true)).single.winner!.id, 'wall');
  });
  test('loads all cursor pages including an empty visibility-filtered page', () async {
    final blocks = FakeUserBlockRepository.pending()..completeInitial({});
    final calls = <Map<String, Object?>>[];
    final repo = WeeklyChallengesRepositoryImpl.withCaller(
      WallRemixRepository(FakeFirestoreClient(), blocks),
      ChallengeAdmissionTracker(InMemoryLocalStore()),
      (name, args) async {
        calls.add(args);
        return name == 'listWeeklyChallenges'
            ? {
                'challenges': [challengeMap()],
                'nextCursor': args.containsKey('cursor') ? null : 'older',
              }
            : {
                'challenge': challengeMap(),
                'entries': <Object?>[],
                'myEntryCount': 0,
                'nextCursor': args.containsKey('cursor') ? null : 'entry-page',
              };
      },
    );
    expect((await repo.get('2026-10-26', ChallengeSort.top)).entries, isEmpty);
    expect(calls.last['cursor'], 'entry-page');
    expect(await repo.list(past: true), hasLength(2));
    expect(calls.last['cursor'], 'older');
  });
  for (final (code, message, error) in [
    ('unauthenticated', '', ChallengeError.signedOut),
    ('resource-exhausted', 'daily-limit', ChallengeError.dailyLimit),
    ('failed-precondition', 'own-entry', ChallengeError.ownEntry),
    ('failed-precondition', 'entry-limit', ChallengeError.entryLimit),
    ('failed-precondition', 'challenge-closed', ChallengeError.closed),
    ('not-found', 'entry-missing', ChallengeError.missing),
  ]) {
    test('maps callable $message to typed error', () async {
      final blocks = FakeUserBlockRepository.pending()..completeInitial({});
      final repo = WeeklyChallengesRepositoryImpl.withCaller(
        WallRemixRepository(FakeFirestoreClient(), blocks),
        ChallengeAdmissionTracker(InMemoryLocalStore()),
        (_, args) async => throw FirebaseFunctionsException(code: code, message: message),
      );
      await expectLater(
        repo.setVote('2026-10-26', 'entry', vote: true),
        throwsA(isA<ChallengeException>().having((e) => e.error, 'error', error)),
      );
    });
  }
}
