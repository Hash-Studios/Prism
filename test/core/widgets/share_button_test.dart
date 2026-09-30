import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  testWidgets('share calls the card share with the full image and context line, and tracks the format', (tester) async {
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);

    final List<String?> calls = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareButton(
            id: 'wall-1',
            source: WallpaperSource.prism,
            url: 'https://img.test/full.jpg',
            thumbUrl: 'https://img.test/thumb.jpg',
            contextLine: 'by Akshay',
            shareCard:
                (BuildContext context, {required String imageUrl, required String link, String? contextLine}) async {
                  calls
                    ..add(imageUrl)
                    ..add(contextLine);
                  return ShareFormatValue.card;
                },
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump(const Duration(seconds: 1));

    expect(calls, <String?>['https://img.test/full.jpg', 'by Akshay']);
    final InviteShareResultEvent result = analytics.events.whereType<InviteShareResultEvent>().single;
    expect(result.format, ShareFormatValue.card);
  });
}
