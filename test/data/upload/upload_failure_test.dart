import 'package:Prism/data/upload/upload_failure.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

UploadFailure _failure(String code, String message) =>
    UploadFailure.from(FirebaseFunctionsException(code: code, message: message));

void main() {
  test('weekly limit maps to a paywall failure', () {
    final failure = _failure('resource-exhausted', 'Free weekly wallpaper upload limit reached.');
    expect(failure.message, 'You reached this week’s free upload limit.');
    expect(failure.weeklyLimit, isTrue);
  });

  test('daily limit does not offer the paywall', () {
    final failure = _failure('resource-exhausted', 'Daily upload limit reached.');
    expect(failure.message, 'You reached today’s upload limit. Try again tomorrow.');
    expect(failure.weeklyLimit, isFalse);
  });

  test('in progress uploads get a wait message', () {
    final failure = _failure('resource-exhausted', 'Upload is already in progress.');
    expect(failure.message, contains('already in progress'));
    expect(failure.weeklyLimit, isFalse);
  });

  test('size and type errors have clear messages', () {
    expect(_failure('invalid-argument', 'File is too large.').message, oversizeUploadMessage);
    expect(_failure('invalid-argument', 'Only image files are allowed.').message, contains('JPG, PNG, WebP or HEIC'));
    expect(_failure('invalid-argument', 'Invalid file path.').message, genericUploadFailureMessage);
  });

  test('other errors fall back to the generic message', () {
    expect(_failure('internal', 'GitHub request failed (500).').message, genericUploadFailureMessage);
    expect(UploadFailure.from(StateError('boom')).message, genericUploadFailureMessage);
    expect(_failure('unauthenticated', 'Sign in to upload files.').message, 'Sign in again to upload.');
  });

  test('upload names carry the uid and time and keep the thumb_ prefix', () {
    final name = uploadFileName(uid: 'abc123', epochMs: 1700000000000, basename: 'pic.jpg');
    expect(name, 'abc123_1700000000000_pic.jpg');
    expect(uploadThumbName(name), 'thumb_abc123_1700000000000_pic.jpg');
  });

  test('the client limit matches the server limit of 15 MiB', () {
    expect(maxUploadBytes, 15 * 1024 * 1024);
  });
}
