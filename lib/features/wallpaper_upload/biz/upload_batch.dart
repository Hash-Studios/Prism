import 'dart:io';

import 'package:Prism/core/purchases/upload_quota.dart';

/// Most images one Prism Pro batch can hold.
const int maxProBatchSize = 10;

/// How many images the picker may return. Free users get what is left of this week's quota.
int uploadPickLimit({required bool isPremium, required int remainingFree}) =>
    isPremium ? maxProBatchSize : remainingFree.clamp(0, UploadQuota.freeUploadsPerWeek);

enum UploadItemOutcome { pending, submitted, skipped, failed }

/// A queue of picked images that go through the single-upload screens one after the other.
class UploadBatch {
  UploadBatch(List<File> files)
    : assert(files.isNotEmpty),
      files = List<File>.unmodifiable(files),
      outcomes = List<UploadItemOutcome>.filled(files.length, UploadItemOutcome.pending);

  final List<File> files;
  final List<UploadItemOutcome> outcomes;
  int index = 0;

  int get total => files.length;
  int get position => index + 1;
  File get current => files[index];
  bool get isMulti => total > 1;
  bool get hasNext => index + 1 < total;
  int get submittedCount => outcomes.where((o) => o == UploadItemOutcome.submitted).length;

  void finishCurrent(UploadItemOutcome outcome) => outcomes[index] = outcome;

  void advance() {
    if (hasNext) index++;
  }

  String get summary {
    final int notSent = total - submittedCount;
    final String sent = '$submittedCount of $total wallpapers submitted';
    return notSent == 0 ? sent : '$sent. $notSent not sent.';
  }
}
