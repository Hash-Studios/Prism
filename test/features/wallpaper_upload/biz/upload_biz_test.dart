import 'dart:io';

import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uploadQualityWarnings', () {
    test('a sharp portrait image has no warning', () {
      expect(uploadQualityWarnings(width: 1080, height: 2400), isEmpty);
    });

    test('warns when the short side is under 1080 px', () {
      expect(uploadQualityWarnings(width: 720, height: 1600), <UploadQualityWarning>[
        UploadQualityWarning.lowResolution,
      ]);
    });

    test('warns about a landscape image, and about its short side', () {
      expect(uploadQualityWarnings(width: 3000, height: 2000), <UploadQualityWarning>[UploadQualityWarning.landscape]);
      expect(uploadQualityWarnings(width: 1600, height: 900), <UploadQualityWarning>[
        UploadQualityWarning.lowResolution,
        UploadQualityWarning.landscape,
      ]);
    });
  });

  group('submission metadata', () {
    test('tags are lower case, without #, and trimmed to the limit', () {
      expect(normalizeSubmissionTag('  #Neon  City '), 'neon city');
      expect(normalizeSubmissionTag('###'), isNull);
      expect(normalizeSubmissionTag('x' * 40), hasLength(maxSubmissionTagLength));
    });

    test('General is the first category and the default', () {
      expect(submissionCategories.first, defaultSubmissionCategory);
      expect(const SubmissionMetadata().category, 'General');
      expect(submissionCategories, contains('Nature'));
      expect(submissionCategories.toSet(), hasLength(submissionCategories.length));
    });

    test('hasTitle ignores blank titles', () {
      expect(const SubmissionMetadata(title: '  ').hasTitle, isFalse);
      expect(const SubmissionMetadata(title: 'Dunes').hasTitle, isTrue);
    });
  });

  group('uploadPickLimit', () {
    test('free users get what is left of the weekly quota', () {
      expect(uploadPickLimit(isPremium: false, remainingFree: 2), 2);
      expect(uploadPickLimit(isPremium: false, remainingFree: 0), 0);
      expect(uploadPickLimit(isPremium: false, remainingFree: 99), UploadQuota.freeUploadsPerWeek);
    });

    test('Prism Pro users get ten per batch', () {
      expect(uploadPickLimit(isPremium: true, remainingFree: 0), 10);
    });
  });

  group('UploadBatch', () {
    final files = <File>[File('a.png'), File('b.png'), File('c.png')];

    test('steps through the files and counts what was sent', () {
      final batch = UploadBatch(files);
      expect((batch.position, batch.total, batch.isMulti), (1, 3, true));
      expect(batch.current.path, 'a.png');

      batch.finishCurrent(UploadItemOutcome.submitted);
      expect(batch.hasNext, isTrue);
      batch.advance();
      batch.finishCurrent(UploadItemOutcome.skipped);
      batch.advance();
      expect(batch.hasNext, isFalse);
      batch.finishCurrent(UploadItemOutcome.failed);

      expect(batch.outcomes, <UploadItemOutcome>[
        UploadItemOutcome.submitted,
        UploadItemOutcome.skipped,
        UploadItemOutcome.failed,
      ]);
      expect(batch.submittedCount, 1);
      expect(batch.summary, '1 of 3 wallpapers submitted. 2 not sent.');
    });

    test('advance stops at the last file', () {
      final batch = UploadBatch(files)
        ..advance()
        ..advance()
        ..advance();
      expect(batch.position, 3);
    });

    test('summary is short when every file was sent', () {
      final batch = UploadBatch(<File>[File('a.png'), File('b.png')]);
      batch.finishCurrent(UploadItemOutcome.submitted);
      batch.advance();
      batch.finishCurrent(UploadItemOutcome.submitted);
      expect(batch.summary, '2 of 2 wallpapers submitted');
      expect(UploadBatch(<File>[File('a.png')]).isMulti, isFalse);
    });
  });
}
