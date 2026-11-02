import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:flutter_test/flutter_test.dart';

WallRequest _request({bool mine = false, WallRequestStatus status = WallRequestStatus.open, bool hidden = false}) =>
    WallRequest.fromMap(<String, Object?>{
      'id': 'r1',
      'mine': mine,
      'status': status == WallRequestStatus.filled ? 'filled' : 'open',
      'hidden': hidden,
    });

void main() {
  group('WallRequest.fromMap', () {
    test('reads every field of a full map', () {
      final WallRequest request = WallRequest.fromMap(<String, Object?>{
        'id': 'r1',
        'text': 'Neon tokyo street',
        'tags': <Object?>['Neon', 'dreamy', 3],
        'voteCount': 12,
        'status': 'filled',
        'createdAtMs': 1000,
        'requesterName': 'Ana',
        'requesterPhoto': 'https://example.com/p.png',
        'mine': true,
        'voted': true,
        'hidden': true,
        'filledWallId': 'w1',
        'filledWallThumb': 'https://example.com/t.jpg',
        'filledBy': 'creator',
        'filledAtMs': 2000,
      });

      expect(request.id, 'r1');
      expect(request.text, 'Neon tokyo street');
      expect(request.tags, <String>['Neon', 'dreamy']);
      expect(request.voteCount, 12);
      expect(request.status, WallRequestStatus.filled);
      expect(request.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(request.requesterName, 'Ana');
      expect(request.requesterPhoto, 'https://example.com/p.png');
      expect(request.mine, isTrue);
      expect(request.voted, isTrue);
      expect(request.hidden, isTrue);
      expect(request.filledWallId, 'w1');
      expect(request.filledWallThumb, 'https://example.com/t.jpg');
      expect(request.filledBy, WallRequestFiller.creator);
      expect(request.filledAt, DateTime.fromMillisecondsSinceEpoch(2000));
    });

    test('an empty map gets the defaults', () {
      final WallRequest request = WallRequest.fromMap(const <String, Object?>{});

      expect(request.id, '');
      expect(request.text, '');
      expect(request.tags, isEmpty);
      expect(request.voteCount, 0);
      expect(request.status, WallRequestStatus.open);
      expect(request.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(request.requesterName, '');
      expect(request.requesterPhoto, '');
      expect(request.mine, isFalse);
      expect(request.voted, isFalse);
      expect(request.hidden, isFalse);
      expect(request.filledWallId, '');
      expect(request.filledWallThumb, '');
      expect(request.filledBy, isNull);
      expect(request.filledAt, isNull);
    });
  });

  group('canVote', () {
    test('another user open visible request takes a vote', () {
      expect(_request().canVote, isTrue);
    });

    test('own request does not take a vote', () {
      expect(_request(mine: true).canVote, isFalse);
    });

    test('filled request does not take a vote', () {
      expect(_request(status: WallRequestStatus.filled).canVote, isFalse);
    });

    test('hidden request does not take a vote', () {
      expect(_request(hidden: true).canVote, isFalse);
    });
  });

  group('WallRequestTab.fromWire', () {
    test('new maps to newest', () {
      expect(WallRequestTab.fromWire('new'), WallRequestTab.newest);
    });

    test('an unknown value maps to top', () {
      expect(WallRequestTab.fromWire('x'), WallRequestTab.top);
    });
  });
}
