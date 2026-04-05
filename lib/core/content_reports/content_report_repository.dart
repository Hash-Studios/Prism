import 'package:Prism/core/utils/result.dart';

/// Submits UGC reports via [submitContentReport] Cloud Function.
abstract class ContentReportRepository {
  /// [contentType] is `wall` or `setup` (server-enforced).
  Future<Result<void>> submitReport({
    required String contentType,
    required String targetFirestoreDocId,
    required String reason,
    String details = '',
    String appVersion = '',
  });
}
