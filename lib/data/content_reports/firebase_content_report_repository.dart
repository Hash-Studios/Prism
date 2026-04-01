import 'package:Prism/core/content_reports/content_report_repository.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:injectable/injectable.dart';

@LazySingleton(as: ContentReportRepository)
class FirebaseContentReportRepository implements ContentReportRepository {
  FirebaseContentReportRepository();

  static const String _region = 'asia-south1';
  static const Duration _timeout = Duration(seconds: 25);

  cf.FirebaseFunctions get _functions => cf.FirebaseFunctions.instanceFor(region: _region);

  @override
  Future<Result<void>> submitReport({
    required String contentType,
    required String targetFirestoreDocId,
    required String reason,
    String details = '',
    String appVersion = '',
  }) async {
    final String ct = contentType.trim();
    final String tid = targetFirestoreDocId.trim();
    if (ct.isEmpty || tid.isEmpty || reason.trim().isEmpty) {
      return Result.error(const ServerFailure('Invalid report.'));
    }
    try {
      final cf.HttpsCallable callable = _functions.httpsCallable(
        'submitContentReport',
        options: cf.HttpsCallableOptions(timeout: _timeout),
      );
      await callable.call(<String, dynamic>{
        'contentType': ct,
        'targetFirestoreDocId': tid,
        'reason': reason.trim(),
        'details': details.trim(),
        'appVersion': appVersion.trim(),
      });
      return Result.success<void>(null);
    } on cf.FirebaseFunctionsException catch (e) {
      return Result.error(ServerFailure(e.message ?? e.code));
    } catch (e) {
      return Result.error(ServerFailure('Failed to submit report: $e'));
    }
  }
}
