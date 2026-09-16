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

class CapturedBreadcrumb {
  CapturedBreadcrumb({required this.message, required this.category, required this.severity, required this.data});

  final String message;
  final String category;
  final ErrorSeverity severity;
  final Map<String, Object?> data;
}

class FakeErrorReporter extends ErrorReporter {
  FakeErrorReporter({bool isEnabled = true}) : _isEnabled = isEnabled;

  bool _isEnabled;

  @override
  bool get isEnabled => _isEnabled;

  set isEnabled(bool value) => _isEnabled = value;

  final List<CapturedException> capturedExceptions = <CapturedException>[];
  final List<CapturedMessage> capturedMessages = <CapturedMessage>[];
  final List<CapturedBreadcrumb> breadcrumbs = <CapturedBreadcrumb>[];

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
  }) async {
    breadcrumbs.add(CapturedBreadcrumb(message: message, category: category, severity: severity, data: data));
  }

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
