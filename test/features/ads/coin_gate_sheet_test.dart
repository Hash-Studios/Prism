import 'package:Prism/features/ads/views/widgets/coin_gate_sheet.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Proxima Nova')
          ..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Extrabold.otf')))
        .load();
    await (FontLoader('Fraunces')..addFont(rootBundle.load('assets/fonts/Fraunces-Variable.ttf'))).load();
  });

  testWidgets('coin gate preserves its shape and returns the chosen option', (tester) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                answer = await showCoinGateSheet<String>(
                  context,
                  title: 'Download',
                  cost: 0,
                  message: (_) => 'Choose an option',
                  options: const [CoinGateOption(label: 'Continue', value: 'download')],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.text('Choose an option')))! as ModalBottomSheetRoute;
    expect(route.useSafeArea, isFalse);
    expect(route.shape, const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(answer, 'download');
  });

  testWidgets('coin gate scrolls at 320px width and 1.3 text scale in light and dark themes', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final ThemeData theme in <ThemeData>[kLightTheme3, kDarkTheme8]) {
      String? answer;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => answer = await showCoinGateSheet<String>(
                  context,
                  title: 'Download wallpaper',
                  cost: 20,
                  message: (_) => 'Choose one of these options to keep going with your download.',
                  options: const [
                    CoinGateOption(label: 'Watch an ad to continue', value: 'watch'),
                    CoinGateOption(label: 'Cancel and return', value: 'cancel', outlined: true),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('Download wallpaper'), findsOneWidget);
      expect(find.text('Watch an ad to continue'), findsOneWidget);
      final Color messageColor = tester
          .renderObject<RenderParagraph>(find.text('Choose one of these options to keep going with your download.'))
          .text
          .style!
          .color!;
      final ModalBottomSheetRoute route =
          ModalRoute.of(tester.element(find.text('Choose one of these options to keep going with your download.')))!
              as ModalBottomSheetRoute;
      expect(route.backgroundColor, theme.colorScheme.surface);
      expect(_contrastRatio(messageColor, route.backgroundColor!), greaterThanOrEqualTo(3));
      await tester.ensureVisible(find.text('Cancel and return'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel and return'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(answer, 'cancel');
    }
  });

  testWidgets('option labels stay visible against their theme backgrounds', (tester) async {
    for (final ThemeData theme in <ThemeData>[kLightTheme3, kDarkTheme8]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCoinGateSheet<void>(
                  context,
                  title: 'Download',
                  cost: 0,
                  message: (_) => 'Choose an option',
                  options: const [
                    CoinGateOption(label: 'Continue', value: null),
                    CoinGateOption(label: 'Cancel', value: null, outlined: true),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final Color filledForeground = tester.renderObject<RenderParagraph>(find.text('Continue')).text.style!.color!;
      final Color outlinedForeground = tester.renderObject<RenderParagraph>(find.text('Cancel')).text.style!.color!;
      final ModalBottomSheetRoute route = ModalRoute.of(tester.element(find.text('Cancel')))! as ModalBottomSheetRoute;
      expect(_contrastRatio(filledForeground, theme.colorScheme.primary), greaterThanOrEqualTo(3));
      expect(route.backgroundColor, theme.colorScheme.surface);
      expect(_contrastRatio(outlinedForeground, route.backgroundColor!), greaterThanOrEqualTo(3));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final Color composited = Color.alphaBlend(foreground, background);
  final double foregroundLuminance = composited.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();
  final double lighter = foregroundLuminance > backgroundLuminance ? foregroundLuminance : backgroundLuminance;
  final double darker = foregroundLuminance > backgroundLuminance ? backgroundLuminance : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
