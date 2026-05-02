import 'package:Prism/core/analytics/analytics_event_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

enum _GenerationMode { fast }

void main() {
  const AnalyticsEventNormalizer normalizer = AnalyticsEventNormalizer();

  group('AnalyticsEventNormalizer', () {
    test('maps legacy aliases to canonical event names', () {
      expect(normalizer.normalizeEventName('reportSetup'), 'report_setup');
      expect(normalizer.normalizeEventName('reportWall'), 'report_wall');
    });

    test('keeps valid event names and normalizes invalid event names', () {
      expect(normalizer.normalizeEventName('coin_earned'), 'coin_earned');
      expect(normalizer.normalizeEventName('Paywall Result'), 'paywall_result');
      expect(normalizer.normalizeEventName('aiGenerateStarted'), 'ai_generate_started');
    });

    test('normalizes parameter keys and values to provider-safe primitives', () {
      final NormalizedAnalyticsEvent event = normalizer.normalizeEvent(
        name: 'reportSetup',
        parameters: <String, Object?>{
          'generationId': 'gen_1',
          'isPremium': true,
          'createdAt': DateTime.utc(2026, 2, 19, 12),
          'metadata': <String, Object?>{'active': false, 'count': 2},
          'tags': <Object?>['alpha', true, 3],
          'mode': _GenerationMode.fast,
          'nullValue': null,
        },
      );

      expect(event.name, 'report_setup');
      expect(event.parameters['generation_id'], 'gen_1');
      expect(event.parameters['is_premium'], 1);
      expect(event.parameters['created_at'], '2026-02-19T12:00:00.000Z');
      expect(event.parameters['metadata'], '{"active":0,"count":2}');
      expect(event.parameters['tags'], '["alpha",1,3]');
      expect(event.parameters['mode'], 'fast');
      expect(event.parameters.containsKey('null_value'), isFalse);
    });

    test('normalizes screen names', () {
      expect(normalizer.normalizeScreenName('/'), 'root');
      expect(normalizer.normalizeScreenName('/User/Profile'), 'user_profile');
      expect(normalizer.normalizeScreenName('homeFeed'), 'home_feed');
    });

    test('normalizes property names', () {
      expect(normalizer.normalizePropertyName('subscriptionTier'), 'subscription_tier');
      expect(normalizer.normalizePropertyName('is-premium'), 'is_premium');
      expect(normalizer.normalizePropertyName('   '), 'unknown_property');
    });
  });
}
