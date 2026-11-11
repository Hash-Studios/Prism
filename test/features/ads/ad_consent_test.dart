import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  setUp(AnalyticsRuntime.reset);
  tearDown(AnalyticsRuntime.reset);

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

  test('ads wait for the tracking answer, and tracking is asked only once', () async {
    final steps = <String>[];
    final answer = Completer<void>();
    final consent = AdConsent(
      requestInfoUpdate: () async => steps.add('update'),
      showFormIfRequired: () async => steps.add('form'),
      canRequestAds: () async {
        steps.add('can');
        return true;
      },
      requestTracking: () {
        steps.add('tracking');
        return answer.future;
      },
    );

    final ensured = consent.ensure();
    final shown = consent.canShow();
    await pumpEventQueue();
    expect(steps, isNot(contains('can')));

    answer.complete();
    expect(await ensured, isTrue);
    expect(await shown, isTrue);
    expect(steps.where((step) => step == 'tracking'), hasLength(1));
  });

  test('a failed tracking request refuses ads and can be retried', () async {
    var attempts = 0;
    final consent = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
      requestTracking: () async {
        if (attempts++ == 0) throw StateError('no channel');
      },
    );

    expect(await consent.ensure(), isFalse);
    await pumpEventQueue();
    expect(await consent.ensure(), isTrue);
    expect(await consent.canShow(), isTrue);
    expect(attempts, 2);
  });

  testWidgets('pending tracking times out and a later request can succeed', (tester) async {
    final firstAttempt = Completer<void>();
    var attempts = 0;
    final consent = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
      requestTracking: () {
        attempts++;
        return attempts == 1 ? firstAttempt.future : Future<void>.value();
      },
    );

    bool? ensuredResult;
    bool? shownResult;
    unawaited(consent.ensure().then((value) => ensuredResult = value));
    unawaited(consent.canShow().then((value) => shownResult = value));
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));

    expect(ensuredResult, isFalse);
    expect(shownResult, isFalse);
    firstAttempt.complete();
    await tester.pump();
    expect(await consent.ensure(), isTrue);
    expect(await consent.canShow(), isTrue);
    expect(attempts, 2);
  });

  testWidgets('an unresolved tracking status is retryable on iOS', (tester) async {
    const channel = MethodChannel('prism/tracking');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final statuses = <Object?>['notDetermined', 'authorized', null, 'authorized', 'unknown', 'authorized'];
      var attempts = 0;
      messenger.setMockMethodCallHandler(channel, (call) async => statuses[attempts++]);

      for (final status in <Object?>['notDetermined', null, 'unknown']) {
        final consent = AdConsent(
          requestInfoUpdate: () async {},
          showFormIfRequired: () async {},
          canRequestAds: () async => true,
        );

        expect(await consent.ensure(), isFalse, reason: 'status: $status');
        await tester.pump();
        expect(await consent.ensure(), isTrue, reason: 'retry after $status');
      }
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('denied and restricted tracking statuses are terminal on iOS', (tester) async {
    const channel = MethodChannel('prism/tracking');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      for (final status in <String>['denied', 'restricted']) {
        messenger.setMockMethodCallHandler(channel, (call) async => status);
        final consent = AdConsent(
          requestInfoUpdate: () async {},
          showFormIfRequired: () async {},
          canRequestAds: () async => true,
        );

        expect(await consent.ensure(), isTrue, reason: 'status: $status');
      }
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('missing tracking plugin refuses ads promptly and can be retried', (tester) async {
    const channel = MethodChannel('prism/tracking');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      messenger.setMockMethodCallHandler(channel, (_) async => throw MissingPluginException());
      final consent = AdConsent(
        requestInfoUpdate: () async {},
        showFormIfRequired: () async {},
        canRequestAds: () async => true,
      );

      expect(await consent.ensure(), isFalse);
      messenger.setMockMethodCallHandler(channel, (call) async => 'authorized');
      await tester.pump();
      expect(await consent.ensure(), isTrue);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('UMP form does not start while tracking is pending', () async {
    final steps = <String>[];
    final tracking = Completer<void>();
    final consent = AdConsent(
      requestInfoUpdate: () async => steps.add('update'),
      showFormIfRequired: () async => steps.add('form'),
      canRequestAds: () async => true,
      requestTracking: () {
        steps.add('tracking');
        return tracking.future;
      },
    );

    final ensured = consent.ensure();
    await pumpEventQueue();

    expect(steps, <String>['tracking']);
    tracking.complete();
    expect(await ensured, isTrue);
    expect(steps, <String>['tracking', 'update', 'form']);
  });

  test('an ensure started before privacy options cannot return true afterward', () async {
    final update = Completer<void>();
    final consent = AdConsent(
      requestInfoUpdate: () => update.future,
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
      showPrivacyOptions: () async {},
    );

    final ensured = consent.ensure();
    await pumpEventQueue();
    await consent.showPrivacyOptions();
    update.complete();

    expect(await ensured, isFalse);
  });

  test('an ads query overlapping privacy options cannot return true afterward', () async {
    final adsQuery = Completer<bool>();
    var queries = 0;
    final consent = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () {
        queries++;
        return queries == 1 ? adsQuery.future : Future<bool>.value(true);
      },
      showPrivacyOptions: () async {},
    );

    final ensured = consent.ensure();
    await pumpEventQueue();
    await consent.showPrivacyOptions();
    adsQuery.complete(true);

    expect(await ensured, isFalse);
    await pumpEventQueue();
    expect(await consent.ensure(), isTrue);
    expect(queries, 2);
  });

  test('ensure refuses to run while privacy options are open', () async {
    final privacyForm = Completer<void>();
    var updates = 0;
    final consent = AdConsent(
      requestInfoUpdate: () async => updates++,
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
      showPrivacyOptions: () => privacyForm.future,
    );

    final opening = consent.showPrivacyOptions();
    expect(await consent.ensure(), isFalse);
    expect(updates, 0);
    privacyForm.complete();
    await opening;
  });

  group('analytics', () {
    late FakeAppAnalytics fakeAnalytics;

    setUp(() {
      fakeAnalytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = fakeAnalytics;
    });

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
