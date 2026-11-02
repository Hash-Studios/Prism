import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';

class ResubmissionSeed {
  const ResubmissionSeed({required this.rejectedDocId, required this.metadata, required this.previousReason});
  final String rejectedDocId;
  final SubmissionMetadata metadata;
  final String previousReason;
}
