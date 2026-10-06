import 'dart:async';

import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
