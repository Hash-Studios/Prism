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
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> copied = <String>[];

  setUp(() {
    copied.clear();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
      }
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpAbout(WidgetTester tester, Future<List<Contributor>> Function() loader) async {
    tester.view.physicalSize = const Size(1000, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AboutScreen(loadContributors: loader)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the brand, links, team, contributors and more', (tester) async {
    await pumpAbout(
      tester,
      () async => <Contributor>[
        Contributor(login: 'ada', contributions: 120),
        Contributor(login: 'grace', contributions: 80),
        Contributor(login: 'linus', contributions: 1),
        Contributor(login: 'extra', contributions: 7),
      ],
    );

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Prism'), findsOneWidget);
    for (final String chip in <String>[
      'GitHub',
      'Rate Prism',
      'X',
      'Instagram',
      'Feedback',
      'Privacy',
      'Terms',
      'Telegram',
    ]) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('ada'), findsOneWidget);
    expect(find.text('120 commits'), findsOneWidget);
    expect(find.text('1 commit'), findsOneWidget);
    expect(find.text('Contributors'), findsOneWidget);
    expect(find.text('extra'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Wallpaper sources'), findsOneWidget);
    expect(find.text('Made in India with Flutter'), findsOneWidget);
  });

  testWidgets('a failed team load offers a retry', (tester) async {
    int calls = 0;
    await pumpAbout(tester, () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return <Contributor>[Contributor(login: 'ada', contributions: 3)];
    });

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ada'), findsOneWidget);
  });

  testWidgets('tapping the version copies it', (tester) async {
    await pumpAbout(tester, () async => <Contributor>[]);

    await tester.tap(find.textContaining('Version '));
    await tester.pump();

    expect(copied, hasLength(1));
    expect(copied.single, contains('+'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('wallpaper sources opens a sheet with the API links', (tester) async {
    await pumpAbout(tester, () async => <Contributor>[]);

    await tester.tap(find.text('Wallpaper sources'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('WallHaven API'), findsOneWidget);
    expect(find.text('Pexels API'), findsOneWidget);
  });

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
      expect(find.textContaining("Couldn't load the team"), findsOneWidget);

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
      expect(find.text('Contributors'), findsOneWidget);
    });

    testWidgets('a link that cannot open shows its address with a Copy action', (tester) async {
      contributorsLoader = () async => <Contributor>[];
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _RecordingUrlLauncher(opens: false);
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await pumpAbout(tester);

      await tester.tap(find.text('GitHub'));
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

      await tester.tap(find.text('Feedback'));
      // Glint loops, so pump a bounded time instead of settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(launcher.urls.single, startsWith('mailto:hash.studios.inc@gmail.com'));
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.byKey(const Key('report_problem_preview')), findsOneWidget);
    });

    testWidgets("What's new reopens the changelog popup", (tester) async {
      contributorsLoader = () async => <Contributor>[];
      await pumpAbout(tester);

      await tester.tap(find.text("What's new"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('See the full changelog'), findsOneWidget);
    });
  });
}
