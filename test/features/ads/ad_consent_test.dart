import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  test('asks for an update, shows the form if required, then reports canRequestAds', () async {
    final steps = <String>[];
    final consent = AdConsent(
      requestInfoUpdate: () async => steps.add('update'),
      showFormIfRequired: () async => steps.add('form'),
      canRequestAds: () async {
        steps.add('can');
        return true;
      },
    );

    expect(await consent.ensure(), isTrue);
    expect(steps, <String>['update', 'form', 'can']);
  });

  test('runs once per session while consent is granted', () async {
    var updates = 0;
    final consent = AdConsent(
      requestInfoUpdate: () async => updates++,
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
    );

    await consent.ensure();
    await consent.ensure();

    expect(updates, 1);
  });

  test('a failed update falls back to the stored consent and never throws', () async {
    final consent = AdConsent(
      requestInfoUpdate: () async => throw StateError('offline'),
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
    );

    expect(await consent.ensure(), isTrue);
  });

  test('a refusal is retried on the next call', () async {
    var updates = 0;
    final consent = AdConsent(
      requestInfoUpdate: () async => updates++,
      showFormIfRequired: () async {},
      canRequestAds: () async => updates > 1,
    );

    expect(await consent.ensure(), isFalse);
    await pumpEventQueue();
    expect(await consent.ensure(), isTrue);
    expect(updates, 2);
  });

  test('an update that never answers is cut off by the timeout', () async {
    final consent = AdConsent(
      requestInfoUpdate: () => Completer<void>().future,
      showFormIfRequired: () async {},
      canRequestAds: () async => false,
      updateTimeout: const Duration(milliseconds: 10),
    );

    expect(await consent.ensure(), isFalse);
  });

  group('privacy options', () {
    test('privacyOptionsRequired reports what the consent form says', () async {
      final required = AdConsent(privacyOptionsRequired: () async => true);
      final notRequired = AdConsent(privacyOptionsRequired: () async => false);

      expect(await required.privacyOptionsRequired(), isTrue);
      expect(await notRequired.privacyOptionsRequired(), isFalse);
    });

    test('privacyOptionsRequired is false when the status cannot be read', () async {
      final consent = AdConsent(privacyOptionsRequired: () async => throw StateError('no plugin'));

      expect(await consent.privacyOptionsRequired(), isFalse);
    });

    test('showPrivacyOptions opens the form', () async {
      var opened = 0;
      final consent = AdConsent(showPrivacyOptions: () async => opened++);

      await consent.showPrivacyOptions();

      expect(opened, 1);
    });

    test('showPrivacyOptions never throws', () async {
      final consent = AdConsent(showPrivacyOptions: () async => throw StateError('form failed'));

      await consent.showPrivacyOptions();
    });
  });

  group('analytics', () {
    late FakeAppAnalytics fakeAnalytics;

    setUp(() {
      fakeAnalytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = fakeAnalytics;
    });
    tearDown(AnalyticsRuntime.reset);

    Future<List<String>> statuses(bool canRequest) async {
      final consent = AdConsent(
        requestInfoUpdate: () async {},
        showFormIfRequired: () async {},
        canRequestAds: () async => canRequest,
      );
      await consent.ensure();
      await pumpEventQueue();
      return fakeAnalytics.events.whereType<AdConsentResultEvent>().map((e) => e.status).toList();
    }

    test('a granted consent is reported as can_request', () async {
      expect(await statuses(true), <String>['can_request']);
    });

    test('a refused consent is reported as refused', () async {
      expect(await statuses(false), <String>['refused']);
    });
  });
}
