import 'package:Prism/env/env.dart';

class SentryConfig {
  const SentryConfig({
    required this.dsn,
    required this.environment,
    required this.release,
    required this.dist,
    required this.enabled,
  });

  final String dsn;
  final String environment;
  final String release;
  final String dist;
  final bool enabled;

  static const String _autoEnabledValue = 'auto';

  factory SentryConfig.fromEnvironment({
    required String fallbackEnvironment,
    String fallbackRelease = '',
    String fallbackDist = '',
  }) {
    const String rawDsn = Env.sentryDsn;
    const String rawEnvironment = Env.sentryEnvironment;
    const String rawRelease = Env.sentryRelease;
    const String rawDist = Env.sentryDist;
    const String rawEnabled = Env.sentryEnabled;

    return SentryConfig.fromRaw(
      dsn: rawDsn,
      environment: rawEnvironment,
      release: rawRelease,
      dist: rawDist,
      enabledValue: rawEnabled,
      fallbackEnvironment: fallbackEnvironment,
      fallbackRelease: fallbackRelease,
      fallbackDist: fallbackDist,
    );
  }

  factory SentryConfig.fromRaw({
    required String dsn,
    required String environment,
    required String release,
    required String dist,
    required String enabledValue,
    required String fallbackEnvironment,
    String fallbackRelease = '',
    String fallbackDist = '',
  }) {
    final String normalizedDsn = Env.normalize(dsn);

    final String normalizedEnvironmentInput = Env.normalize(environment);
    final String normalizedEnvironment = normalizedEnvironmentInput.isEmpty
        ? Env.normalize(fallbackEnvironment)
        : normalizedEnvironmentInput;

    final String normalizedReleaseInput = Env.normalize(release);
    final String normalizedRelease = normalizedReleaseInput.isEmpty
        ? Env.normalize(fallbackRelease)
        : normalizedReleaseInput;

    final String normalizedDistInput = Env.normalize(dist);
    final String normalizedDist = normalizedDistInput.isEmpty ? Env.normalize(fallbackDist) : normalizedDistInput;

    final bool enabled = SentryConfig.resolveEnabled(Env.normalize(enabledValue), normalizedDsn);

    return SentryConfig(
      dsn: normalizedDsn,
      environment: normalizedEnvironment,
      release: normalizedRelease,
      dist: normalizedDist,
      enabled: enabled,
    );
  }

  static bool resolveEnabled(String rawEnabled, String dsn) {
    final String normalized = Env.normalize(rawEnabled).toLowerCase();
    if (normalized.isEmpty || normalized == _autoEnabledValue) {
      return dsn.isNotEmpty;
    }
    if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
      return true;
    }
    if (normalized == '0' || normalized == 'false' || normalized == 'no') {
      return false;
    }
    return dsn.isNotEmpty;
  }
}
