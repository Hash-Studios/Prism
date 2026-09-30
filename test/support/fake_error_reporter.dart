import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class CapturedException {
  CapturedException({
    required this.exception,
    this.stackTrace,
    this.message,
    required this.severity,
    this.tag,
    required this.extras,
  });

  final Object exception;
  final StackTrace? stackTrace;
  final String? message;
  final ErrorSeverity severity;
  final String? tag;
  final Map<String, Object?> extras;
}

class CapturedMessage {
  CapturedMessage({required this.message, required this.severity, this.tag, required this.extras});

  final String message;
  final ErrorSeverity severity;
  final String? tag;
  final Map<String, Object?> extras;
}

class FakeErrorReporter extends ErrorReporter {
  @override
  bool get isEnabled => true;

  final List<CapturedException> capturedExceptions = <CapturedException>[];
  final List<CapturedMessage> capturedMessages = <CapturedMessage>[];

  String? lastUserId;
  String? lastUserEmail;
  String? lastUsername;
  bool cleared = false;

  @override
  Future<void> addBreadcrumb({
    required String message,
    String category = 'app.lifecycle',
    ErrorSeverity severity = ErrorSeverity.info,
    Map<String, Object?> data = const <String, Object?>{},
  }) async {}

  @override
  Future<SentryId?> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? message,
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) async {
    capturedExceptions.add(
      CapturedException(
        exception: exception,
        stackTrace: stackTrace,
        message: message,
        severity: severity,
        tag: tag,
        extras: extras,
      ),
    );
    return null;
  }

  @override
  Future<SentryId?> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) async {
    capturedMessages.add(CapturedMessage(message: message, severity: severity, tag: tag, extras: extras));
    return null;
  }

  @override
  Future<void> setUser({required String id, required String email, String? username}) async {
    cleared = false;
    lastUserId = id;
    lastUserEmail = email;
    lastUsername = username;
  }

  @override
  Future<void> clearUser() async {
    cleared = true;
    lastUserId = null;
    lastUserEmail = null;
    lastUsername = null;
  }
}
