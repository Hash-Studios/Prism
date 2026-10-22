import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/popup/popup_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

void main() {
  testWidgets('link chips launch their destination and report each actual launch result', (tester) async {
    var succeeds = true;
    final opened = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'launch');
      opened.add((call.arguments as Map)['url'] as String);
      return succeeds;
    });
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      AnalyticsRuntime.reset();
    });
    final destinations = <String, LinkDestinationValue>{
      'https://github.com/Hash-Studios/Prism': LinkDestinationValue.github,
      'https://play.google.com/store/apps/details?id=com.prism': LinkDestinationValue.playStore,
      'https://twitter.com/prism': LinkDestinationValue.twitter,
      'https://instagram.com/prism': LinkDestinationValue.instagram,
      'https://t.me/prism': LinkDestinationValue.telegram,
      'hash.studios.inc@gmail.com': LinkDestinationValue.email,
      'https://example.test': LinkDestinationValue.external,
    };
    for (final entry in destinations.entries) {
      succeeds = entry.value != LinkDestinationValue.external;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupLinkChip(icon: Icons.link, label: 'Website', link: entry.key),
          ),
        ),
      );
      await tester.tap(find.text('Website'));
      await tester.pump();

      expect(opened.last, entry.value == LinkDestinationValue.email ? 'mailto:${entry.key}' : entry.key);
      final tap = analytics.events.whereType<SurfaceActionTappedEvent>().last;
      expect(tap.sourceContext, 'about_screen_action_chip_website');
      final result = analytics.events.whereType<ExternalLinkOpenResultEvent>().last;
      expect(result.destination, entry.value);
      expect(result.result, succeeds ? EventResultValue.success : EventResultValue.failure);
      expect(result.reason, succeeds ? null : AnalyticsReasonValue.error);
    }
    expect(analytics.events.whereType<SurfaceActionTappedEvent>(), hasLength(7));
    expect(analytics.events.whereType<ExternalLinkOpenResultEvent>(), hasLength(7));
  });
}
