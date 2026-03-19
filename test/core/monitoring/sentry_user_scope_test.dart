import 'package:Prism/core/monitoring/error_reporter.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/monitoring/sentry_user_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _UserScopeReporter extends ErrorReporter {
  @override
  bool get isEnabled => true;

  String? id;
  String? email;
  String? username;
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
  Future<void> clearUser() async {
    cleared = true;
    id = null;
    email = null;
    username = null;
  }

  @override
  Future<void> setUser({required String id, required String email, String? username}) async {
    cleared = false;
    this.id = id;
    this.email = email;
    this.username = username;
  }
}

void main() {
  group('syncSentryUserScope', () {
    late _UserScopeReporter reporter;

    setUp(() {
      reporter = _UserScopeReporter();
      MonitoringRuntime.reporter = reporter;
    });

    tearDown(() {
      MonitoringRuntime.reset();
    });

    test('sets user scope when logged in with id and email', () async {
      await syncSentryUserScope(loggedIn: true, id: 'user-1', email: 'user@example.com', username: 'tester');

      expect(reporter.cleared, isFalse);
      expect(reporter.id, 'user-1');
      expect(reporter.email, 'user@example.com');
      expect(reporter.username, 'tester');
    });

    test('clears user scope when logged out', () async {
      await syncSentryUserScope(loggedIn: false, id: 'user-1', email: 'user@example.com');

      expect(reporter.cleared, isTrue);
      expect(reporter.id, isNull);
      expect(reporter.email, isNull);
    });

    test('clears user scope when mandatory fields are missing', () async {
      await syncSentryUserScope(loggedIn: true, id: '', email: 'user@example.com');

      expect(reporter.cleared, isTrue);
      expect(reporter.id, isNull);
    });
  });
}
