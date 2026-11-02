import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, List<String>> _fonts = <String, List<String>>{
  'Proxima Nova': <String>['assets/fonts/ProximaNova-Regular.otf', 'assets/fonts/Proxima Nova Bold.otf'],
  'Satoshi': <String>[
    'assets/fonts/Satoshi-Regular.otf',
    'assets/fonts/Satoshi-Medium.otf',
    'assets/fonts/Satoshi-Bold.otf',
  ],
};

const List<Locale> _locales = <Locale>[
  Locale('en'),
  Locale('de'),
  Locale('es'),
  Locale('hi'),
  Locale('id'),
  Locale('pt', 'BR'),
];

Widget _host(Locale locale, double scale, Widget Function(AppLocalizations l10n) child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: prismLightThemes.first.theme,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Padding(padding: const EdgeInsets.all(20), child: child(context.l10n)),
    ),
  ),
);

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) => fontSize * (fontSize <= 14 ? 2 : 3);

  @override
  @Deprecated('Use scale instead')
  double get textScaleFactor => 2;
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.descendant(of: find.text(text), matching: find.byType(RichText)));

int _lineCount(RenderParagraph paragraph) => paragraph
    .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length))
    .map((box) => box.top.round())
    .toSet()
    .length;

void main() {
  setUpAll(() async {
    for (final MapEntry<String, List<String>> font in _fonts.entries) {
      final FontLoader loader = FontLoader(font.key);
      for (final String asset in font.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });

  setUp(() {
    final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(360, 780);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });

  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  for (final Locale locale in _locales) {
    for (final double scale in <double>[1, 1.3, 2]) {
      testWidgets('set targets in $locale at ${scale}x on a 360px phone are never cut or broken mid-word', (
        tester,
      ) async {
        late List<String> labels;
        await tester.pumpWidget(
          _host(locale, scale, (l10n) {
            labels = <String>[l10n.setScreenTargetHome, l10n.setScreenTargetLock, l10n.setScreenTargetBoth];
            return PrismSegmented<int>(
              values: const <int>[0, 1, 2],
              selected: 2,
              labelOf: (v) => labels[v],
              onChanged: (_) {},
            );
          }),
        );

        for (final String label in labels) {
          final RenderParagraph paragraph = _paragraph(tester, label);
          expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is cut');
          expect(_lineCount(paragraph), lessThanOrEqualTo(label.split(' ').length), reason: '"$label" breaks mid-word');
        }
      });
    }
  }

  testWidgets('a label that fits keeps the reader text size', (tester) async {
    await tester.pumpWidget(
      _host(
        const Locale('en'),
        1.3,
        (_) => PrismSegmented<int>(
          values: const <int>[0, 1],
          selected: 0,
          labelOf: (v) => <String>['Lock', 'Home'][v],
          onChanged: (_) {},
        ),
      ),
    );

    expect(_paragraph(tester, 'Lock').textScaler, const TextScaler.linear(1.3));
  });

  testWidgets('localized labels fit under a nonlinear text scaler', (tester) async {
    const _NonlinearTextScaler scaler = _NonlinearTextScaler();
    await tester.pumpWidget(
      MaterialApp(
        theme: prismLightThemes.first.theme,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: app!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: PrismSegmented<int>(
                values: const <int>[0, 1],
                selected: 0,
                labelOf: (value) => value == 0 ? 'Home screen' : 'Lock screen',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final RenderParagraph paragraph = _paragraph(tester, 'Home screen');
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(_lineCount(paragraph), lessThanOrEqualTo(2));
  });

  testWidgets('the page title wraps instead of being cut at 2x text on a 360px phone', (tester) async {
    await tester.pumpWidget(
      _host(const Locale('en'), 2, (l10n) => PrismHeader(title: l10n.premiumPageTitle, onBack: () {})),
    );

    expect(_paragraph(tester, 'Prism Premium').didExceedMaxLines, isFalse);
  });

  testWidgets('the localized ClockOverlay Set action wraps at 2x text on a 360px phone', (tester) async {
    late String label;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: prismLightThemes.first.theme,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: app!,
        ),
        home: Builder(
          builder: (context) {
            label = context.l10n.wallpaperPreviewSetHome;
            return const ClockOverlay(
              link: '',
              file: true,
              request: SetScreenRequest(url: ''),
            );
          },
        ),
      ),
    );

    final RenderParagraph paragraph = _paragraph(tester, label);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(_lineCount(paragraph), lessThanOrEqualTo(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
