import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fullData() => <String, dynamic>{
  'wallDocId': 'wall_doc_1',
  'shareId': 'share_1',
  'creatorUid': 'uid_1',
  'state': 'pending',
  'reason': 'Too soft',
  'thumb': <String, dynamic>{'url': 'https://example.com/thumb.webp', 'width': 960, 'height': 600},
  'source': <String, dynamic>{'width': 2560, 'height': 1600, 'aspect': '16:10'},
  'wallThumb': 'https://example.com/wall.webp',
  'wallTitle': 'Dune',
  'creatorName': 'Asha',
  'replaces': true,
  'createdAt': DateTime.utc(2026, 11, 1, 12),
};

void main() {
  test('fromData parses a full map', () {
    final DesktopSubmission? submission = DesktopSubmission.fromData('sub_1', _fullData());

    expect(submission, isNotNull);
    expect(submission!.id, 'sub_1');
    expect(submission.wallDocId, 'wall_doc_1');
    expect(submission.shareId, 'share_1');
    expect(submission.creatorUid, 'uid_1');
    expect(submission.state, DesktopSubmissionState.pending);
    expect(submission.reason, 'Too soft');
    expect(submission.thumbUrl, 'https://example.com/thumb.webp');
    expect(submission.sourceWidth, 2560);
    expect(submission.sourceHeight, 1600);
    expect(submission.aspect, '16:10');
    expect(submission.wallThumb, 'https://example.com/wall.webp');
    expect(submission.wallTitle, 'Dune');
    expect(submission.creatorName, 'Asha');
    expect(submission.replaces, isTrue);
    expect(submission.createdAt, DateTime.utc(2026, 11, 1, 12));
  });

  test('fromData returns null when the thumb url is missing', () {
    final Map<String, dynamic> data = _fullData()..['thumb'] = <String, dynamic>{'width': 960, 'height': 600};

    expect(DesktopSubmission.fromData('sub_1', data), isNull);
  });

  test('fromData returns null for an unknown state', () {
    final Map<String, dynamic> data = _fullData()..['state'] = 'archived';

    expect(DesktopSubmission.fromData('sub_1', data), isNull);
  });
}
