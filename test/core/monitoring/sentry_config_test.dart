import 'package:Prism/core/monitoring/sentry_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SentryConfig', () {
    test('fromEnvironment uses fallback values when defines are empty', () {
      final SentryConfig config = SentryConfig.fromEnvironment(
        fallbackEnvironment: 'staging',
        fallbackRelease: 'Prism@2.6.9+77',
        fallbackDist: '77',
      );

      expect(config.environment, 'staging');
      expect(config.release, 'Prism@2.6.9+77');
      expect(config.dist, '77');
      expect(config.enabled, isFalse);
    });

    test('auto enabled mode depends on dsn presence', () {
      final SentryConfig disabled = SentryConfig.fromRaw(
        dsn: '',
        environment: '',
        release: '',
        dist: '',
        enabledValue: 'auto',
        fallbackEnvironment: 'staging',
      );
      final SentryConfig enabled = SentryConfig.fromRaw(
        dsn: 'https://public@example.ingest.sentry.io/123',
        environment: '',
        release: '',
        dist: '',
        enabledValue: 'auto',
        fallbackEnvironment: 'staging',
      );

      expect(disabled.enabled, isFalse);
      expect(enabled.enabled, isTrue);
    });

    test('explicit enabled flag overrides dsn default behavior', () {
      final SentryConfig forceEnabled = SentryConfig.fromRaw(
        dsn: '',
        environment: 'production',
        release: '',
        dist: '',
        enabledValue: 'true',
        fallbackEnvironment: 'staging',
      );
      final SentryConfig forceDisabled = SentryConfig.fromRaw(
        dsn: 'https://public@example.ingest.sentry.io/123',
        environment: 'production',
        release: '',
        dist: '',
        enabledValue: 'false',
        fallbackEnvironment: 'staging',
      );

      expect(forceEnabled.enabled, isTrue);
      expect(forceDisabled.enabled, isFalse);
    });

    test('normalizes explicit values over fallbacks', () {
      final SentryConfig config = SentryConfig.fromRaw(
        dsn: ' https://public@example.ingest.sentry.io/123 ',
        environment: 'production',
        release: 'Prism@3.0.0+90',
        dist: '90',
        enabledValue: 'auto',
        fallbackEnvironment: 'staging',
        fallbackRelease: 'fallback-release',
        fallbackDist: 'fallback-dist',
      );

      expect(config.dsn, 'https://public@example.ingest.sentry.io/123');
      expect(config.environment, 'production');
      expect(config.release, 'Prism@3.0.0+90');
      expect(config.dist, '90');
      expect(config.enabled, isTrue);
    });
  });
}
