import 'package:Prism/core/monitoring/monitoring_runtime.dart';

Future<void> syncSentryUserScope({
  required bool loggedIn,
  required String id,
  required String email,
  String? username,
}) async {
  final String normalizedId = id.trim();
  final String normalizedEmail = email.trim();
  final String normalizedUsername = (username ?? '').trim();

  if (!loggedIn || normalizedId.isEmpty || normalizedEmail.isEmpty) {
    await MonitoringRuntime.reporter.clearUser();
    return;
  }

  await MonitoringRuntime.reporter.setUser(
    id: normalizedId,
    email: normalizedEmail,
    username: normalizedUsername.isEmpty ? null : normalizedUsername,
  );
}
