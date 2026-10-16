import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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
      // Glint loops, so pump a bounded time instead of settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

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

      expect(find.text('See the full changelog'), findsOneWidget);
    });

    testWidgets("keeps master's sections in master's order, built from Prism components", (tester) async {
      contributorsLoader = () async => <Contributor>[
        _contributor('ada', commits: 120),
        _contributor('grace', commits: 80),
        _contributor('linus', commits: 1),
        _contributor('extra', commits: 7),
      ];
      await pumpAbout(tester);

      expect(find.byType(PrismPage), findsOneWidget);
      expect(find.byType(PrismChip), findsNWidgets(9));
      expect(find.byType(PrismGroup), findsNWidgets(2));
      expect(find.byType(PrismAvatar), findsNWidgets(4));
      expect(find.byType(PrismSectionHeader), findsNWidgets(2));
      for (final String chip in <String>[
        'GITHUB',
        'RATE',
        'FEEDBACK',
        "WHAT'S NEW",
        'PRIVACY',
        'TERMS',
        'TWITTER',
        'INSTAGRAM',
        'TELEGRAM',
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }

      double top(Finder finder) => tester.getTopLeft(finder.first).dy;
      final List<double> order = <double>[
        top(find.text('About')),
        top(find.byType(Image)),
        top(find.text('Prism Wallpapers')),
        top(find.textContaining('Version ')),
        top(find.text('A feature-rich wallpaper manager.')),
        top(find.text('GITHUB')),
        top(find.text('The Team')),
        top(find.text('ada')),
        top(find.text('Other Contributors')),
        top(find.text('extra')),
        top(find.text('Wallpaper sources')),
        top(find.text('Made with ❤ in India with Flutter!')),
      ];
      expect(order, orderedEquals(<double>[...order]..sort()), reason: "sections follow master's order");
      expect(find.text('1 commit'), findsOneWidget);
      expect(find.text('7 commits'), findsOneWidget);
    });

    testWidgets('the podium puts the top contributor in the middle and largest', (tester) async {
      contributorsLoader = () async => <Contributor>[_contributor('ada'), _contributor('grace'), _contributor('linus')];
      await pumpAbout(tester);

      expect(tester.getCenter(find.text('grace')).dx, lessThan(tester.getCenter(find.text('ada')).dx));
      expect(tester.getCenter(find.text('ada')).dx, lessThan(tester.getCenter(find.text('linus')).dx));
      // The avatars sit in rank order 2, 1, 3 from left to right.
      final Size middle = tester.getSize(find.byType(PrismAvatar).at(1));
      expect(middle.width, greaterThan(tester.getSize(find.byType(PrismAvatar).at(0)).width));
      expect(middle.width, greaterThan(tester.getSize(find.byType(PrismAvatar).at(2)).width));
    });

    testWidgets('tapping a podium member opens the contributor sheet', (tester) async {
      contributorsLoader = () async => <Contributor>[_contributor('ada')];
      await pumpAbout(tester);

      await tester.tap(find.text('ada'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The test binding blocks the GitHub lookup, so the sheet shows its error state.
      expect(find.text('Could not load this profile'), findsOneWidget);
    });

    testWidgets('tapping an other contributor opens their profile link', (tester) async {
      contributorsLoader = () async => <Contributor>[
        _contributor('a'),
        _contributor('b'),
        _contributor('c'),
        _contributor('dave'),
      ];
      final launcher = _RecordingUrlLauncher(opens: true);
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await pumpAbout(tester);

      await tester.tap(find.text('dave'));
      await tester.pump();
      await tester.pump();

      expect(launcher.urls, contains('https://github.com/dave'));
    });

    testWidgets('the header shows a hairline only once the page is scrolled', (tester) async {
      contributorsLoader = () async => <Contributor>[
        for (final String login in <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) _contributor(login),
      ];
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
      await tester.pump();
      await tester.pump();

      double hairline() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity;
      expect(hairline(), 0);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(hairline(), 1);
    });

    testWidgets('the header has the Prism back button', (tester) async {
      contributorsLoader = () async => <Contributor>[];
      await pumpAbout(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('About sections stay reachable on a narrow screen at 2x text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final List<Contributor> contributors = <Contributor>[
        _contributor('a_very_long_contributor_login_for_a_narrow_screen', commits: 120),
        _contributor('another_long_contributor_login', commits: 80),
        _contributor('third_long_contributor_login', commits: 40),
        _contributor('other_contributor_login_for_the_list', commits: 7),
      ];

      await tester.pumpWidget(MaterialApp(home: AboutScreen(loadContributors: () async => contributors)));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final Finder aboutListScrollable = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(find.text('The Team'), 100, scrollable: aboutListScrollable);
      await tester.pump();
      expect(find.text('The Team'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Other Contributors'), 100, scrollable: aboutListScrollable);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('other_contributor_login_for_the_list'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Wallpaper sources'), 100, scrollable: aboutListScrollable);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Wallpaper sources'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('WallHaven API'), findsOneWidget);
    });
  });
}
