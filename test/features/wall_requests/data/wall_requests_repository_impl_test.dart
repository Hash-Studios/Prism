import 'package:Prism/features/wall_requests/data/wall_requests_repository_impl.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

Map<Object?, Object?> _requestMap({String id = 'r1', String text = 'Neon tokyo street'}) => <Object?, Object?>{
  'id': id,
  'text': text,
  'tags': <Object?>['Neon', 'Cyberpunk'],
  'voteCount': 7,
  'status': 'filled',
  'createdAtMs': 1000,
  'requesterName': 'Ana',
  'requesterPhoto': 'https://example.com/p.png',
  'mine': true,
  'voted': true,
  'hidden': false,
  'filledWallId': 'w1',
  'filledWallThumb': 'https://example.com/t.jpg',
  'filledBy': 'studio',
  'filledAtMs': 2000,
};

void main() {
  late List<String> names;
  late List<Map<String, Object?>> payloads;
  late Future<Object?> Function(String name, Map<String, Object?> data) respond;
  late WallRequestsRepositoryImpl repo;

  setUp(() {
    names = <String>[];
    payloads = <Map<String, Object?>>[];
    respond = (String name, Map<String, Object?> data) async => null;
    repo = WallRequestsRepositoryImpl.withCaller((String name, Map<String, Object?> data) {
      names.add(name);
      payloads.add(data);
      return respond(name, data);
    });
  });

  group('list', () {
    test('calls listWallRequests with the tab wire value and parses the rows', () async {
      respond = (_, _) async => <Object?, Object?>{
        'requests': <Object?>[_requestMap()],
      };

      final List<WallRequest> requests = await repo.list(WallRequestTab.newest);

      expect(names, <String>['listWallRequests']);
      expect(payloads.single, <String, Object?>{'tab': 'new'});
      expect(requests, hasLength(1));
      final WallRequest request = requests.single;
      expect(request.id, 'r1');
      expect(request.text, 'Neon tokyo street');
      expect(request.tags, <String>['Neon', 'Cyberpunk']);
      expect(request.voteCount, 7);
      expect(request.status, WallRequestStatus.filled);
      expect(request.mine, isTrue);
      expect(request.voted, isTrue);
      expect(request.filledBy, WallRequestFiller.studio);
      expect(request.filledAt, DateTime.fromMillisecondsSinceEpoch(2000));
      expect(request.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('a response without a requests list is unknown', () async {
      respond = (_, _) async => <Object?, Object?>{'requests': 'nope'};

      await expectLater(
        repo.list(WallRequestTab.top),
        throwsA(isA<WallRequestException>().having((e) => e.error, 'error', WallRequestError.unknown)),
      );
    });

    test('a response that is not a map is unknown', () async {
      respond = (_, _) async => 'nope';

      await expectLater(
        repo.list(WallRequestTab.top),
        throwsA(isA<WallRequestException>().having((e) => e.error, 'error', WallRequestError.unknown)),
      );
    });
  });

  group('create', () {
    test('created returns WallRequestCreated and sends the payload', () async {
      respond = (_, _) async => <Object?, Object?>{'status': 'created', 'request': _requestMap()};

      final CreateWallRequestResult result = await repo.create(text: 'Neon tokyo', tags: <String>['Neon']);

      expect(names, <String>['createWallRequest']);
      expect(payloads.single, <String, Object?>{
        'text': 'Neon tokyo',
        'tags': <String>['Neon'],
        'force': false,
      });
      expect(result, isA<WallRequestCreated>());
      expect(result.request.id, 'r1');
    });

    test('force is sent as true when asked', () async {
      respond = (_, _) async => <Object?, Object?>{'status': 'created', 'request': _requestMap()};

      await repo.create(text: 'Neon tokyo', tags: <String>[], force: true);

      expect(payloads.single['force'], isTrue);
    });

    test('duplicate returns WallRequestDuplicate with exact from the response', () async {
      respond = (_, _) async => <Object?, Object?>{'status': 'duplicate', 'exact': true, 'request': _requestMap()};

      final CreateWallRequestResult result = await repo.create(text: 'Neon tokyo', tags: <String>[]);

      expect(result, isA<WallRequestDuplicate>());
      expect((result as WallRequestDuplicate).exact, isTrue);
      expect(result.request.id, 'r1');
    });

    test('duplicate without exact is not exact', () async {
      respond = (_, _) async => <Object?, Object?>{'status': 'duplicate', 'request': _requestMap()};

      final CreateWallRequestResult result = await repo.create(text: 'Neon tokyo', tags: <String>[]);

      expect((result as WallRequestDuplicate).exact, isFalse);
    });

    test('an unknown status is unknown', () async {
      respond = (_, _) async => <Object?, Object?>{'status': 'weird', 'request': _requestMap()};

      await expectLater(
        repo.create(text: 'Neon tokyo', tags: <String>[]),
        throwsA(isA<WallRequestException>().having((e) => e.error, 'error', WallRequestError.unknown)),
      );
    });
  });

  group('setVote', () {
    test('sends the vote and returns the server count', () async {
      respond = (_, _) async => <Object?, Object?>{'voted': true, 'voteCount': 8};

      final int count = await repo.setVote('r1', vote: true);

      expect(names, <String>['setWallRequestVote']);
      expect(payloads.single, <String, Object?>{'requestId': 'r1', 'vote': true});
      expect(count, 8);
    });

    test('a response without a count is unknown', () async {
      respond = (_, _) async => <Object?, Object?>{'voted': true};

      await expectLater(
        repo.setVote('r1', vote: true),
        throwsA(isA<WallRequestException>().having((e) => e.error, 'error', WallRequestError.unknown)),
      );
    });
  });

  group('setHidden', () {
    test('sends requestId and hidden', () async {
      respond = (_, _) async => null;

      await repo.setHidden('r1', hidden: true);

      expect(names, <String>['setWallRequestHidden']);
      expect(payloads.single, <String, Object?>{'requestId': 'r1', 'hidden': true});
    });
  });

  group('error mapping', () {
    final List<(String, String, WallRequestError)> rows = <(String, String, WallRequestError)>[
      ('unauthenticated', '', WallRequestError.signedOut),
      ('invalid-argument', 'text-rejected', WallRequestError.textRejected),
      ('resource-exhausted', 'daily-limit', WallRequestError.dailyLimit),
      ('failed-precondition', 'own-request', WallRequestError.ownRequest),
      ('failed-precondition', 'request-closed', WallRequestError.closed),
      ('failed-precondition', 'account-too-new', WallRequestError.accountTooNew),
      ('failed-precondition', 'account-closed', WallRequestError.unknown),
      ('not-found', 'request-missing', WallRequestError.missing),
      ('internal', '', WallRequestError.unknown),
    ];

    for (final (String code, String message, WallRequestError expected) in rows) {
      test('$code / "$message" maps to $expected', () async {
        respond = (_, _) async => throw FirebaseFunctionsException(code: code, message: message);

        await expectLater(
          repo.setVote('r1', vote: true),
          throwsA(isA<WallRequestException>().having((e) => e.error, 'error', expected)),
        );
      });
    }

    test('any other exception is unknown', () async {
      respond = (_, _) async => throw StateError('boom');

      await expectLater(
        repo.list(WallRequestTab.top),
        throwsA(isA<WallRequestException>().having((e) => e.error, 'error', WallRequestError.unknown)),
      );
    });
  });
}
