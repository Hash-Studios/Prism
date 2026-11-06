import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _FakeCaller {
  _FakeCaller(this.handler);

  final Future<Object?> Function(String name, Map<String, Object?> data) handler;
  final List<String> names = <String>[];
  final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];

  Future<Object?> call(String name, Map<String, Object?> data) {
    names.add(name);
    payloads.add(data);
    return handler(name, data);
  }
}

Future<Object?> Function(String, Map<String, Object?>) _throwing(String code, String message) =>
    (String name, Map<String, Object?> data) => throw cf.FirebaseFunctionsException(message: message, code: code);

DesktopSubmissionRepository _repo(_FakeCaller caller) =>
    DesktopSubmissionRepository.withCaller(FakeFirestoreClient(), caller.call);

Matcher _failedWith(DesktopSubmitFailure failure) =>
    throwsA(isA<DesktopSubmitException>().having((DesktopSubmitException e) => e.failure, 'failure', failure));

void main() {
  group('submit', () {
    test('sends wallDocId and base64 content and returns the submission id', () async {
      final _FakeCaller caller = _FakeCaller(
        (String name, Map<String, Object?> data) async => <String, Object?>{
          'submissionId': 'sub_9',
          'state': 'pending',
        },
      );
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 250]);

      final String id = await _repo(caller).submit(wallDocId: 'wall_doc_1', bytes: bytes);

      expect(id, 'sub_9');
      expect(caller.names, <String>['submitDesktopVersion']);
      expect(caller.payloads.single, <String, Object?>{
        'wallDocId': 'wall_doc_1',
        'contentBase64': base64Encode(bytes),
      });
    });

    test('maps each image error message to its failure', () async {
      final Map<String, DesktopSubmitFailure> expected = <String, DesktopSubmitFailure>{
        'desktop-not-landscape': DesktopSubmitFailure.notLandscape,
        'desktop-aspect-ratio': DesktopSubmitFailure.wrongAspect,
        'desktop-too-small': DesktopSubmitFailure.tooSmall,
        'desktop-image-invalid': DesktopSubmitFailure.unreadable,
        'desktop-file-too-large': DesktopSubmitFailure.tooLarge,
        'desktop-pending-exists': DesktopSubmitFailure.alreadyPending,
        'desktop-not-owner': DesktopSubmitFailure.notAllowed,
        'desktop-wall-not-approved': DesktopSubmitFailure.notAllowed,
        'desktop-wall-not-found': DesktopSubmitFailure.notAllowed,
      };
      for (final MapEntry<String, DesktopSubmitFailure> entry in expected.entries) {
        final _FakeCaller caller = _FakeCaller(_throwing('invalid-argument', entry.key));

        await expectLater(_repo(caller).submit(wallDocId: 'w', bytes: Uint8List(0)), _failedWith(entry.value));
      }
    });

    test('maps permission-denied and resource-exhausted by code', () async {
      await expectLater(
        _repo(_FakeCaller(_throwing('permission-denied', 'nope'))).submit(wallDocId: 'w', bytes: Uint8List(0)),
        _failedWith(DesktopSubmitFailure.notAllowed),
      );
      await expectLater(
        _repo(_FakeCaller(_throwing('resource-exhausted', 'daily limit'))).submit(wallDocId: 'w', bytes: Uint8List(0)),
        _failedWith(DesktopSubmitFailure.rateLimited),
      );
    });

    test('maps an unknown error to failed', () async {
      await expectLater(
        _repo(_FakeCaller(_throwing('internal', 'boom'))).submit(wallDocId: 'w', bytes: Uint8List(0)),
        _failedWith(DesktopSubmitFailure.failed),
      );
    });
  });

  group('review', () {
    test('sends decision reject with reason and reasonCode', () async {
      final _FakeCaller caller = _FakeCaller(
        (String name, Map<String, Object?> data) async => <String, Object?>{'state': 'rejected'},
      );

      await _repo(
        caller,
      ).review(submissionId: 'sub_9', approve: false, reason: 'Watermark visible', reasonCode: 'watermark');

      expect(caller.names, <String>['reviewDesktopSubmission']);
      expect(caller.payloads.single, <String, Object?>{
        'submissionId': 'sub_9',
        'decision': 'reject',
        'reason': 'Watermark visible',
        'reasonCode': 'watermark',
      });
    });

    test('throws DesktopReviewWallUnavailable when the wall is no longer approved', () async {
      await expectLater(
        _repo(
          _FakeCaller(_throwing('failed-precondition', 'desktop-wall-unavailable')),
        ).review(submissionId: 'sub_9', approve: true),
        throwsA(isA<DesktopReviewWallUnavailable>()),
      );
    });
  });
}
