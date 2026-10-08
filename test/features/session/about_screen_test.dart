import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github/github.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  _RecordingUrlLauncher({required this.opens});

  final bool opens;
  final List<String> urls = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return opens;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Contributor _contributor(String? login, {int commits = 5}) =>
    Contributor(login: login, htmlUrl: login == null ? null : 'https://github.com/$login', contributions: commits);

void main() {
  test('the feedback link is a mailto with the version and platform prefilled', () {
    final link = buildFeedbackLink(version: '3.3.0', build: '339', platform: 'android 14');
    final uri = Uri.parse(link);

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'hash.studios.inc@gmail.com');
    expect(uri.queryParameters['subject'], 'Prism feedback');
    expect(uri.queryParameters['body'], contains('Prism 3.3.0+339'));
    expect(uri.queryParameters['body'], contains('android 14'));
    expect(link, isNot(contains('+android')));
  });

  group('screen', () {
    final copied = <String?>[];

    setUp(() async {
      copied.clear();
      AnalyticsRuntime.instance = FakeAppAnalytics();
      await getIt.reset();
      getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String?);
          return null;
        },
      );
    });

    tearDown(() async {
      contributorsLoader = () =>
          GitHub().repositories.listContributors(RepositorySlug('Hash-Studios', 'Prism')).toList();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      AnalyticsRuntime.reset();
      await getIt.reset();
    });

    Future<void> pumpAbout(WidgetTester tester, {ThemeData? theme}) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: theme, home: const AboutScreen()));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the contributor list loads once per session', (tester) async {
      var loads = 0;
      contributorsLoader = () async {
        loads += 1;
        return <Contributor>[_contributor('ada'), _contributor('grace'), _contributor('linus')];
      };

      await pumpAbout(tester);
      expect(find.text('ada'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpAbout(tester);

      expect(loads, 1);
      expect(find.text('ada'), findsOneWidget);
    });

    testWidgets('a failed load is not cached, and Try again loads again', (tester) async {
      var loads = 0;
      contributorsLoader = () async {
        loads += 1;
        if (loads == 1) throw StateError('rate limited');
        return <Contributor>[_contributor('ada')];
      };

      await pumpAbout(tester);
      expect(find.text("Couldn't load the team"), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(loads, 2);
      expect(find.text('ada'), findsOneWidget);
    });

    testWidgets('a contributor with missing fields does not crash the screen', (tester) async {
      contributorsLoader = () async => <Contributor>[
        _contributor('a'),
        _contributor('b'),
        _contributor('c'),
        Contributor(contributions: 1),
        _contributor('dave', commits: 2),
      ];

      await pumpAbout(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('dave'), findsOneWidget);
      expect(find.text('Other Contributors'), findsOneWidget);
    });

    testWidgets('a link that cannot open shows its address with a Copy action', (tester) async {
      contributorsLoader = () async => <Contributor>[];
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _RecordingUrlLauncher(opens: false);
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await pumpAbout(tester);

      await tester.tap(find.text('GITHUB'));
      await tester.pump();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text("Couldn't open https://www.github.com/Hash-Studios/Prism"), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, <String?>['https://www.github.com/Hash-Studios/Prism']);
    });

    testWidgets('FEEDBACK opens the mail app, and falls back to Report a problem when none opens', (tester) async {
      contributorsLoader = () async => <Contributor>[];
      final launcher = _RecordingUrlLauncher(opens: false);
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (call) async => <String, Object?>{
          'appName': 'Prism',
          'packageName': 'com.hash.prism',
          'version': '3.4.0',
          'buildNumber': '340',
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          null,
        ),
      );
      await pumpAbout(tester);

      await tester.tap(find.text('FEEDBACK'));
      await tester.pumpAndSettle();

      expect(launcher.urls.single, startsWith('mailto:hash.studios.inc@gmail.com'));
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.byKey(const Key('report_problem_preview')), findsOneWidget);
    });

    testWidgets("WHAT'S NEW reopens the changelog popup", (tester) async {
      contributorsLoader = () async => <Contributor>[];
      await pumpAbout(tester);

      await tester.tap(find.text("WHAT'S NEW"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('View full'), findsOneWidget);
    });

    testWidgets('chip icons use the theme accent, even when it is black', (tester) async {
      contributorsLoader = () async => <Contributor>[];
      await pumpAbout(
        tester,
        theme: ThemeData(colorScheme: const ColorScheme.light(error: Colors.black)),
      );

      final chip = tester.widget<ActionChip>(find.widgetWithText(ActionChip, 'GITHUB'));
      expect((chip.avatar! as Icon).color, Colors.black);
    });
  });
}
