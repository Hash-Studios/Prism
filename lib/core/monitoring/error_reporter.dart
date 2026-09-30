import 'package:Prism/core/utils/json_utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

enum ErrorSeverity { debug, info, warning, error, fatal }

abstract class ErrorReporter {
  const ErrorReporter();

  bool get isEnabled;

  Future<SentryId?> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? message,
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  });

  Future<SentryId?> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  });

  Future<void> addBreadcrumb({
    required String message,
    String category = 'app.lifecycle',
    ErrorSeverity severity = ErrorSeverity.info,
    Map<String, Object?> data = const <String, Object?>{},
  });

  Future<void> setUser({required String id, required String email, String? username});

  Future<void> clearUser();
}

class NoopErrorReporter extends ErrorReporter {
  const NoopErrorReporter();

  @override
  bool get isEnabled => false;

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
    return null;
  }

  @override
  Future<SentryId?> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) async {
    return null;
  }

  @override
  Future<void> clearUser() async {}

  @override
  Future<void> setUser({required String id, required String email, String? username}) async {}
}

class SentryErrorReporter extends ErrorReporter {
  const SentryErrorReporter();

  @override
  bool get isEnabled => true;

  @override
  Future<void> addBreadcrumb({
    required String message,
    String category = 'app.lifecycle',
    ErrorSeverity severity = ErrorSeverity.info,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return Sentry.addBreadcrumb(
      Breadcrumb(message: message, category: category, level: _toSentryLevel(severity), data: _normalizeMap(data)),
    );
  }

  @override
  Future<SentryId?> captureException(
    Object exception, {
    StackTrace? stackTrace,
    String? message,
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    return Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = _toSentryLevel(severity);
        if (tag != null && tag.trim().isNotEmpty) {
          scope.setTag('tag', tag.trim());
        }
        final Map<String, Object?> context = _normalizeMap(extras);
        if (message != null && message.trim().isNotEmpty) {
          context['message'] = message.trim();
        }
        _setContext(scope, context);
      },
    );
  }

  @override
  Future<SentryId?> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? tag,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    return Sentry.captureMessage(
      message,
      level: _toSentryLevel(severity),
      withScope: (scope) {
        if (tag != null && tag.trim().isNotEmpty) {
          scope.setTag('tag', tag.trim());
        }
        _setContext(scope, _normalizeMap(extras));
      },
    );
  }

  @override
  Future<void> setUser({required String id, required String email, String? username}) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: id, email: email, username: username));
    });
  }

  @override
  Future<void> clearUser() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  void _setContext(Scope scope, Map<String, Object?> context) {
    if (context.isEmpty) {
      return;
    }
    scope.setContexts('logger', context);
  }
}

SentryLevel _toSentryLevel(ErrorSeverity severity) {
  switch (severity) {
    case ErrorSeverity.debug:
      return SentryLevel.debug;
    case ErrorSeverity.info:
      return SentryLevel.info;
    case ErrorSeverity.warning:
      return SentryLevel.warning;
    case ErrorSeverity.error:
      return SentryLevel.error;
    case ErrorSeverity.fatal:
      return SentryLevel.fatal;
  }
}

Map<String, Object?> _normalizeMap(Map<String, Object?> source) => toJsonSafe(source)! as Map<String, Object?>;
