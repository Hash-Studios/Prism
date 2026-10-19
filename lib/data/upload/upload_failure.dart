import 'package:cloud_functions/cloud_functions.dart';
import 'package:Prism/l10n/l10n.dart';

/// The biggest file the upload callable accepts. Mirrors MAX_UPLOAD_BYTES in functions/src/githubContent.ts.
const int maxUploadBytes = 15 * 1024 * 1024;

enum UploadFailureKind { generic, oversize, weeklyLimit, dailyLimit, inProgress, fileType, signIn }

/// A user-facing reason an upload call failed. [weeklyLimit] is true when a Prism Pro upgrade would fix it.
class UploadFailure {
  const UploadFailure(this.kind);

  static const UploadFailure oversize = UploadFailure(UploadFailureKind.oversize);
  static const UploadFailure generic = UploadFailure(UploadFailureKind.generic);

  bool get weeklyLimit => kind == UploadFailureKind.weeklyLimit;

  String message(AppLocalizations l10n) => switch (kind) {
    UploadFailureKind.generic => l10n.coreUploadFailureGeneric,
    UploadFailureKind.oversize => l10n.coreUploadFailureOversize,
    UploadFailureKind.weeklyLimit => l10n.coreUploadFailureWeeklyLimit,
    UploadFailureKind.dailyLimit => l10n.coreUploadFailureDailyLimit,
    UploadFailureKind.inProgress => l10n.coreUploadFailureInProgress,
    UploadFailureKind.fileType => l10n.coreUploadFailureFileType,
    UploadFailureKind.signIn => l10n.coreUploadFailureSignIn,
  };

  factory UploadFailure.from(Object error) {
    if (error is! FirebaseFunctionsException) return generic;
    final String detail = (error.message ?? '').toLowerCase();
    switch (error.code) {
      case 'resource-exhausted':
        if (detail.contains('weekly')) {
          return const UploadFailure(UploadFailureKind.weeklyLimit);
        }
        if (detail.contains('daily')) {
          return const UploadFailure(UploadFailureKind.dailyLimit);
        }
        return const UploadFailure(UploadFailureKind.inProgress);
      case 'invalid-argument':
        if (detail.contains('too large')) return oversize;
        if (detail.contains('image')) {
          return const UploadFailure(UploadFailureKind.fileType);
        }
        return generic;
      case 'unauthenticated':
        return const UploadFailure(UploadFailureKind.signIn);
      default:
        return generic;
    }
  }

  final UploadFailureKind kind;
}

/// Names a wall upload so two uploads never share a repo path: `<uid>_<epochMs>_<basename>`.
String uploadFileName({required String uid, required int epochMs, required String basename}) =>
    '${uid}_${epochMs}_$basename';

/// The preview file name. The `thumb_` prefix is how the server tells a wall preview from the full image.
String uploadThumbName(String fileName) => 'thumb_$fileName';
