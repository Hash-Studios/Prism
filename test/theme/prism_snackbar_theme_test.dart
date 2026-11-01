import 'package:Prism/l10n/generated/app_localizations_de.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/generated/app_localizations_es.dart';
import 'package:Prism/l10n/generated/app_localizations_hi.dart';
import 'package:Prism/l10n/generated/app_localizations_id.dart';
import 'package:Prism/l10n/generated/app_localizations_pt.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) => fontSize < 10 ? fontSize : fontSize * 2;

  @override
  double get textScaleFactor => 1;
}

void main() {
  setUpAll(() async {
    for (final asset in <String>['assets/fonts/ProximaNova-Regular.otf', 'assets/fonts/Proxima Nova Bold.otf']) {
      await (FontLoader('Proxima Nova')..addFont(rootBundle.load(asset))).load();
    }
  });

  Future<BuildContext> pumpHost(
    WidgetTester tester, {
    required double width,
    required TextScaler scaler,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler, padding: padding),
          child: Builder(
            builder: (context) {
              host = context;
              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(snackBarTheme: prismSnackBarThemeFor(context, Theme.of(context).snackBarTheme)),
                child: child!,
              );
            },
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return host;
  }

  for (final double scale in <double>[0, 0.1, 0.2, 0.5, 0.85]) {
    testWidgets('the snackbar builds at text scale $scale', (tester) async {
      final context = await pumpHost(tester, width: 390, scaler: TextScaler.linear(scale));
      expect(tester.takeException(), isNull);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nonlinear scaling uses the action font size to put Undo below the message', (tester) async {
    final context = await pumpHost(tester, width: 390, scaler: const _NonlinearScaler());
    const label = 'Rückgängig';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Wallpaper set'),
        action: SnackBarAction(label: label, onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text(label)).top, greaterThan(tester.getRect(find.text('Wallpaper set')).bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide snackbar keeps its panel width inside horizontal system padding', (tester) async {
    final context = await pumpHost(
      tester,
      width: 1440,
      scaler: TextScaler.noScaling,
      padding: const EdgeInsets.only(left: 44, right: 34),
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    await tester.pumpAndSettle();
    final card = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
    expect(card.width, PrismLayout.panelWidth);
    expect(card.left, greaterThanOrEqualTo(44));
    expect(card.right, lessThanOrEqualTo(1440 - 34));
  });

  testWidgets('a wrapped action uses the panel width rather than the full viewport', (tester) async {
    final context = await pumpHost(tester, width: 1440, scaler: const TextScaler.linear(2));
    final l10n = AppLocalizationsDe();
    final label = l10n.coreRetryOnScreen(l10n.coreHomeScreen);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.coreWallpaperSet),
        action: SnackBarAction(label: label, onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
    expect(card.width, PrismLayout.panelWidth);
    expect(card.center.dx, 720);
    expect(tester.getRect(find.text(label)).top, greaterThan(tester.getRect(find.text(l10n.coreWallpaperSet)).bottom));
  });

  final locales = <String, AppLocalizations>{
    'en': AppLocalizationsEn(),
    'de': AppLocalizationsDe(),
    'es': AppLocalizationsEs(),
    'hi': AppLocalizationsHi(),
    'id': AppLocalizationsId(),
    'pt': AppLocalizationsPt(),
    'pt-BR': AppLocalizationsPtBr(),
  };
  for (final width in <double>[390, 1024, 1440]) {
    for (final entry in locales.entries) {
      testWidgets('${entry.key} common action labels fit the $width wide snackbar at 2x text', (tester) async {
        final context = await pumpHost(tester, width: width, scaler: const TextScaler.linear(2));
        final l10n = entry.value;
        final labels = <String>{
          l10n.accountCopy,
          l10n.coreUndo,
          l10n.wallpaperFewerLikeThisUndo,
          l10n.coreTryAgain,
          l10n.coreOpenSettings,
          l10n.notifUndo,
          if (width > PrismLayout.panelWidth) l10n.coreBlockCreatorAfterReport,
          l10n.onboardingRecoveryRetry,
        };
        for (final label in labels) {
          var tapped = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.coreWallpaperSet),
              action: SnackBarAction(label: label, onPressed: () => tapped = true),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          final card = tester.getRect(
            find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first,
          );
          expect(card.width, lessThanOrEqualTo(PrismLayout.panelWidth), reason: label);
          final action = find.widgetWithText(TextButton, label);
          final target = tester.getRect(action);
          expect(target.left, greaterThanOrEqualTo(card.left), reason: label);
          expect(target.right, lessThanOrEqualTo(card.right), reason: label);
          expect(target.height, greaterThanOrEqualTo(kMinInteractiveDimension), reason: label);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(tapped, isTrue, reason: label);
        }
      });
    }
  }
}
