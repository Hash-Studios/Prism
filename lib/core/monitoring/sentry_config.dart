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
    final String normalizedDsn = _normalizeDefineValue(dsn);

    final String normalizedEnvironmentInput = _normalizeDefineValue(environment);
    final String normalizedEnvironment = normalizedEnvironmentInput.isEmpty
        ? _normalizeDefineValue(fallbackEnvironment)
        : normalizedEnvironmentInput;

    final String normalizedReleaseInput = _normalizeDefineValue(release);
    final String normalizedRelease = normalizedReleaseInput.isEmpty
        ? _normalizeDefineValue(fallbackRelease)
        : normalizedReleaseInput;

    final String normalizedDistInput = _normalizeDefineValue(dist);
    final String normalizedDist = normalizedDistInput.isEmpty
        ? _normalizeDefineValue(fallbackDist)
        : normalizedDistInput;

    final bool enabled = SentryConfig.resolveEnabled(_normalizeDefineValue(enabledValue), normalizedDsn);

    return SentryConfig(
      dsn: normalizedDsn,
      environment: normalizedEnvironment,
      release: normalizedRelease,
      dist: normalizedDist,
      enabled: enabled,
    );
  }

  static bool resolveEnabled(String rawEnabled, String dsn) {
    final String normalized = _normalizeDefineValue(rawEnabled).toLowerCase();
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

  static String _normalizeDefineValue(String rawValue) => Env.normalize(rawValue);
}
