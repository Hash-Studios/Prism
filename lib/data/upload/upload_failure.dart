import 'package:cloud_functions/cloud_functions.dart';

/// The biggest file the upload callable accepts. Mirrors MAX_UPLOAD_BYTES in functions/src/githubContent.ts.
const int maxUploadBytes = 15 * 1024 * 1024;

const String oversizeUploadMessage = 'This image is over 15 MB. Choose a smaller one.';
const String genericUploadFailureMessage = 'The upload did not finish. Your image is still here, so you can try again.';

/// A user-facing reason an upload call failed. [weeklyLimit] is true when a Prism Pro upgrade would fix it.
class UploadFailure {
  const UploadFailure(this.message, {this.weeklyLimit = false});

  factory UploadFailure.from(Object error) {
    if (error is! FirebaseFunctionsException) return const UploadFailure(genericUploadFailureMessage);
    final String detail = (error.message ?? '').toLowerCase();
    switch (error.code) {
      case 'resource-exhausted':
        if (detail.contains('weekly')) {
          return const UploadFailure('You reached this week’s free upload limit.', weeklyLimit: true);
        }
        if (detail.contains('daily')) {
          return const UploadFailure('You reached today’s upload limit. Try again tomorrow.');
        }
        return const UploadFailure('An upload is already in progress. Wait a moment, then try again.');
      case 'invalid-argument':
        if (detail.contains('too large')) return const UploadFailure(oversizeUploadMessage);
        if (detail.contains('image')) {
          return const UploadFailure('That file type is not supported. Use a JPG, PNG, WebP or HEIC image.');
        }
        return const UploadFailure(genericUploadFailureMessage);
      case 'unauthenticated':
        return const UploadFailure('Sign in again to upload.');
      default:
        return const UploadFailure(genericUploadFailureMessage);
    }
  }

  final String message;
  final bool weeklyLimit;
}

/// Names a wall upload so two uploads never share a repo path: `<uid>_<epochMs>_<basename>`.
String uploadFileName({required String uid, required int epochMs, required String basename}) =>
    '${uid}_${epochMs}_$basename';

/// The preview file name. The `thumb_` prefix is how the server tells a wall preview from the full image.
String uploadThumbName(String fileName) => 'thumb_$fileName';
