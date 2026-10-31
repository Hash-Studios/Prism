import 'package:cloud_functions/cloud_functions.dart';

class FakeReviewCallables {
  FakeReviewCallables(this.docs);

  final Map<String, Map<String, Map<String, dynamic>>> docs;
  final List<({String name, Map<String, Object?> data})> requests = [];
  final Set<String> admittedParents = {};
  final Map<String, Object?> _results = {};
  bool loseNextRejectResponse = false;

  Map<String, Map<String, dynamic>> _collection(String name) => docs.putIfAbsent(name, () => {});
  String _revision(Map<String, dynamic> data) => data.toString();

  Future<Object?> call(String name, Map<String, Object?> data) async {
    requests.add((name: name, data: data));
    if (name == 'getWallResubmissionContext') {
      return {
        'contexts': {
          for (final String id in (data['wallDocIds']! as List).cast<String>())
            id: {
              'verified': false,
              'wallRevision': _collection('walls')[id] == null ? null : _revision(_collection('walls')[id]!),
              'rejectionRevision': _collection('rejectedWalls')[id] == null
                  ? null
                  : _revision(_collection('rejectedWalls')[id]!),
              'rejectionOperationId': _collection('rejectedWalls')[id]?['rejectionOperationId'],
              'hasAdmittedChild': admittedParents.contains(id),
            },
        },
      };
    }
    final String id = data['wallDocId']! as String;
    final String op = (data['operationId'] ?? data['rejectionOperationId'])! as String;
    if (_results.containsKey(op)) return _results[op];
    if (name == 'rejectWallForReview') {
      final wall = _collection('walls')[id];
      if (wall == null ||
          wall['review'] != data['expectedReview'] ||
          _collection('rejectedWalls').containsKey(id) ||
          _revision(wall) != data['expectedWallRevision']) {
        throw FirebaseFunctionsException(code: 'aborted', message: 'wall-changed');
      }
      _collection('rejectedWalls')[id] = {
        ...wall,
        'rejectionReason': data['reason'],
        'rejectionOperationId': op,
        'rejectedAt': DateTime.utc(2026),
        'sourceWallCreateTime': DateTime.utc(2025),
      };
      _collection('walls').remove(id);
      _results[op] = {'wallDocId': id, 'rejectionOperationId': op};
      if (loseNextRejectResponse) {
        loseNextRejectResponse = false;
        throw FirebaseFunctionsException(code: 'unavailable', message: 'response-lost');
      }
      return _results[op];
    }
    if (name == 'undoWallRejection') {
      final archive = _collection('rejectedWalls')[id];
      if (archive == null ||
          _collection('walls').containsKey(id) ||
          admittedParents.contains(id) ||
          _revision(archive) != data['expectedRejectionRevision']) {
        throw FirebaseFunctionsException(code: 'aborted', message: 'rejection-changed-or-already-resubmitted');
      }
      _collection('walls')[id] = Map.of(archive)
        ..remove('rejectionReason')
        ..remove('rejectedAt')
        ..remove('rejectionOperationId')
        ..remove('sourceWallCreateTime');
      _collection('rejectedWalls').remove(id);
      _results[op] = {'wallDocId': id, 'operationId': op};
      return _results[op];
    }
    throw StateError('Unexpected callable: $name');
  }
}
