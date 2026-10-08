import 'dart:convert';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> platformCalls;
  late List<String> toastMessages;
  late List<MethodCall> shareCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    toastMessages = <String>[];
    shareCalls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
      shareCalls.add(call);
      return 'shared';
    });
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    AnalyticsRuntime.reset();
  });

  Future<List<Map<String, dynamic>>> capture(Future<void> Function() body) async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      bodies.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      return http.Response('{"short_url":"https://prismwalls.com/s/abc"}', 200);
    });
    await http.runWithClient(body, () => client);
    return bodies;
  }

  test('a profile link uses the username and never the email', () async {
    final bodies = await capture(
      () => createUserDynamicLink('Ana', 'ana_w', 'ana@example.com', 'Bio', 'https://img/p.png'),
    );

    final request = bodies.single;
    expect(request['canonical_url'], 'https://prismwalls.com/user/ana_w');
    expect(request.toString(), isNot(contains('ana@example.com')));
    expect((request['preview'] as Map)['title'], 'Ana (@ana_w)');
    expect(shareCalls.single.arguments.toString(), contains('https://prismwalls.com/s/abc'));
    expect(shareCalls.single.arguments.toString(), isNot(contains('ana@example.com')));
  });

  test('a name that is an email address is not put in the preview', () async {
    final bodies = await capture(() => createUserDynamicLink('ana@example.com', 'ana_w', 'ana@example.com', '', ''));

    expect((bodies.single['preview'] as Map)['title'], 'ana_w (@ana_w)');
  });

  test('without a username no link is made and the user is told to set one', () async {
    final bodies = await capture(() => createUserDynamicLink('Ana', '  ', 'ana@example.com', '', ''));

    expect(bodies, isEmpty);
    expect(toastMessages, <String>['Set a username to share your profile']);
    expect(shareCalls, isEmpty);
    expect(platformCalls.where((call) => call.method == 'Clipboard.setData'), isEmpty);
  });

  test('the invite preview names the inviter and carries their photo', () async {
    final bodies = await capture(
      () => createSharingPrismLink('uid1', inviterName: 'Ana', inviterPhoto: 'https://img/ana.png'),
    );

    final preview = bodies.single['preview'] as Map;
    expect(preview['title'], 'Ana invited you to Prism');
    expect(preview['image_source_url'], 'https://img/ana.png');
  });

  test('the invite preview falls back to Join Prism for a missing or email name', () async {
    final noName = await capture(() => createSharingPrismLink('uid1'));
    final emailName = await capture(() => createSharingPrismLink('uid1', inviterName: 'ana@example.com'));

    for (final bodies in <List<Map<String, dynamic>>>[noName, emailName]) {
      final preview = bodies.single['preview'] as Map;
      expect(preview['title'], 'Join Prism');
      expect(preview, isNot(contains('image_source_url')));
    }
  });

  test('a wallpaper link preview drops a title that holds an email address', () async {
    final bodies = await capture(() async {
      await createDynamicLink(
        'w1',
        WallpaperSource.prism,
        null,
        'https://img/t.png',
        title: 'Wallpaper by ana@example.com',
      );
    });

    expect((bodies.single['preview'] as Map)['title'], 'Wallpaper on Prism');
  });
}
