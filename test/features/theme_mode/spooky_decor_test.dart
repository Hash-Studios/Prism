import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

class _TickerShell extends StatelessWidget {
  const _TickerShell();

  @override
  Widget build(BuildContext context) => AutoTabsRouter(
    routes: const <PageRouteInfo>[_HomeRoute(), _SearchRoute()],
    builder: (context, child) => Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: child),
          TextButton(onPressed: () => AutoTabsRouter.of(context).setActiveIndex(1), child: const Text('Show search')),
          TextButton(onPressed: () => AutoTabsRouter.of(context).setActiveIndex(0), child: const Text('Show home')),
        ],
      ),
    ),
  );
}

class _HomeRoute extends PageRouteInfo<void> {
  const _HomeRoute() : super('Home');
}

class _SearchRoute extends PageRouteInfo<void> {
  const _SearchRoute() : super('Search');
}

class _TickerRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('Shell', builder: (_) => const _TickerShell()),
      children: <AutoRoute>[
        AutoRoute(
          path: 'home',
          page: PageInfo('Home', builder: (_) => const HomeTabTickerMode(child: SpookySpider())),
        ),
        AutoRoute(
          path: 'search',
          page: PageInfo('Search', builder: (_) => const Text('Search')),
        ),
      ],
    ),
    AutoRoute(
      path: '/detail',
      page: PageInfo('Detail', builder: (_) => const Text('Detail')),
    ),
  ];
}

void main() {
  test('Spooky season ends on 3 November 2026', () {
    expect(isSpookySeason(DateTime(2026, 10, 31)), isTrue);
    expect(isSpookySeason(DateTime(2026, 11, 3)), isFalse);
  });

  testWidgets('Spooky decor draws on the Spooky theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme9,
        home: const Scaffold(body: Stack(children: <Widget>[SpookyWeb(), SpookySpider()])),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });

  testWidgets('Spooky decor draws nothing on the Material theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme,
        home: const Scaffold(body: Stack(children: <Widget>[SpookyWeb(), SpookySpider()])),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('only the Spooky theme draws decor across registered themes and accents', (tester) async {
    const List<int> accents = <int>[0xFFFF7A1A, 0xFF42A5F5, 0xFFE57697];
    final themes = <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes];

    for (final option in themes) {
      for (final accent in accents) {
        await tester.pumpWidget(
          MaterialApp(
            theme: withPrismAccent(option.theme, accent),
            themeAnimationDuration: Duration.zero,
            home: const Scaffold(body: Stack(children: <Widget>[SpookyWeb(), SpookySpider()])),
          ),
        );
        await tester.pump();
        expect(
          find.byType(SvgPicture),
          findsNWidgets(option.id == prismSpookyThemeId ? 2 : 0),
          reason: '${option.id} with accent $accent',
        );
        expect(tester.takeException(), isNull, reason: '${option.id} with accent $accent');
      }
    }
  });

  testWidgets('switching away from Spooky removes decor and reduced motion stops it', (tester) async {
    ThemeData theme = kDarkTheme9;
    bool reduceMotion = false;

    Widget app() => MaterialApp(
      theme: theme,
      themeAnimationDuration: Duration.zero,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Scaffold(body: Stack(children: <Widget>[SpookyWeb(), SpookySpider()])),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    reduceMotion = true;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);

    reduceMotion = false;
    theme = kDarkTheme;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(SvgPicture), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spider eyes use the active custom accent', (tester) async {
    const Color accent = Color(0xFF42A5F5);
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme9.copyWith(colorScheme: kDarkTheme9.colorScheme.copyWith(primary: accent)),
        home: const Scaffold(body: SpookySpider()),
      ),
    );
    final SvgStringLoader loader = tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader as SvgStringLoader;
    final String renderedSource = loader.provideSvg(null);
    expect(renderedSource, contains('fill="#42a5f5"'));
    expect(renderedSource, isNot(contains('fill="#ff7a1a"')));
  });

  testWidgets('AutoTabsRouter stops hidden Home spider callbacks and resumes when Home returns', (tester) async {
    final _TickerRouter router = _TickerRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: kDarkTheme9, routerConfig: router.config()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    router.push(const PageRouteInfo<void>('Detail'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.transientCallbackCount, 0);
    router.pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.tap(find.text('Show search'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Show home'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spooky spider stops animating when motion is reduced', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme9,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Stack(children: <Widget>[SpookySpider()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
