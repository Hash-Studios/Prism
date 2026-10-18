import 'package:Prism/core/analytics/analytics_identity_sync.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  final BufferedAppAnalytics outsideWidgetZone = BufferedAppAnalytics();
  testWidgets('first dispatch uses the caller test zone', (WidgetTester tester) async {
    final _RecordingAnalytics target = _RecordingAnalytics();
    outsideWidgetZone.attach(target);
    outsideWidgetZone.track(const OnboardingStartedEvent());
    await tester.pump();
    expect(target.events, hasLength(1));
    outsideWidgetZone.dispose();
  });

  test('failed dispatch is contained and later events retain order', () async {
    final BufferedAppAnalytics buffer = BufferedAppAnalytics();
    final _FailingAnalytics target = _FailingAnalytics();
    buffer.attach(target);
    await buffer.track(const OnboardingStartedEvent());
    await buffer.track(const TermsAcceptedEvent());
    expect(target.events.map((AnalyticsEvent event) => event.eventName), <String>['terms_accepted']);
  });

  test('replacement restores identity and properties for captured facade', () async {
    final BufferedAppAnalytics buffer = BufferedAppAnalytics();
    buffer.attach(_RecordingAnalytics());
    await buffer.setUserId('first');
    await buffer.setUserProperty(name: 'logged_in', value: '1');
    final _RecordingAnalytics replacement = _RecordingAnalytics();
    buffer.attach(replacement);
    await buffer.track(const TermsAcceptedEvent());
    expect(replacement.calls, <String>['identify:first', 'terms_accepted:first']);
    expect(replacement.userProperties, isNotEmpty);
  });
  test('replays early events in identity order and captured references remain usable', () async {
    final BufferedAppAnalytics buffer = BufferedAppAnalytics();
    await buffer.track(const OnboardingStartedEvent());
    await buffer.setUserId('first');
    await buffer.track(const TermsAcceptedEvent());
    await buffer.setUserId(null);
    await buffer.track(const BrowseAsGuestTappedEvent());
    final _RecordingAnalytics target = _RecordingAnalytics();
    buffer.attach(target);
    await buffer.track(const OnboardingStartedEvent());
    await buffer.flush();
    expect(target.calls, <String>[
      'onboarding_started:guest',
      'identify:first',
      'terms_accepted:first',
      'identify:guest',
      'browse_as_guest_tapped:guest',
      'onboarding_started:guest',
    ]);
  });

  test('overflow discards old events together and preserves current identity', () async {
    final BufferedAppAnalytics buffer = BufferedAppAnalytics(capacity: 32);
    await buffer.setUserId('first');
    for (int i = 0; i < 40; i++) {
      await buffer.track(const OnboardingStartedEvent());
    }
    final _RecordingAnalytics target = _RecordingAnalytics();
    buffer.attach(target);
    await buffer.flush();
    expect(target.events.length, lessThan(32));
    expect(
      target.calls.where((String call) => call.startsWith('onboarding')),
      everyElement('onboarding_started:first'),
    );
  });

  test('expired startup events are dropped and identity survives', () async {
    final BufferedAppAnalytics buffer = BufferedAppAnalytics(maxAge: Duration.zero);
    await buffer.setUserId('first');
    await buffer.track(const OnboardingStartedEvent());
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final _RecordingAnalytics target = _RecordingAnalytics();
    buffer.attach(target);
    await buffer.flush();
    expect(target.events, isEmpty);
    expect(target.userIds, <String?>['first']);
  });

  test('signed in account changes reset before identifying and signout resets once', () async {
    final _RecordingAnalytics target = _RecordingAnalytics();
    final AnalyticsIdentitySync sync = AnalyticsIdentitySync(analytics: target);
    Future<void> identity(String userId) => sync.sync(
      loggedIn: userId.isNotEmpty,
      userId: userId,
      subscriptionTier: 'free',
      isPremium: false,
      sourceTag: 'test',
    );
    await identity('first');
    await identity('second');
    await identity('');
    await identity('');
    expect(target.userIds, <String?>['first', null, 'second', null]);
  });

  test('dispose cancels buffered startup data', () async {
    final BufferedAppAnalytics buffer = BufferedAppAnalytics();
    await buffer.track(const OnboardingStartedEvent());
    buffer.dispose();
    final _RecordingAnalytics target = _RecordingAnalytics();
    buffer.attach(target);
    await buffer.track(const TermsAcceptedEvent());
    expect(target.events, isEmpty);
  });
}

class _FailingAnalytics extends FakeAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) {
    if (event is OnboardingStartedEvent) throw StateError('SDK unavailable');
    return super.track(event);
  }
}

class _RecordingAnalytics extends FakeAppAnalytics {
  final List<String> calls = <String>[];
  String _identity = 'guest';

  @override
  Future<void> setUserId(String? userId) async {
    _identity = userId ?? 'guest';
    calls.add('identify:$_identity');
    await super.setUserId(userId);
  }

  @override
  Future<void> track(AnalyticsEvent event) async {
    calls.add('${event.eventName}:$_identity');
    await super.track(event);
  }
}
