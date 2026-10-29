import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    for (final asset in <String>['assets/fonts/ProximaNova-Regular.otf', 'assets/fonts/Proxima Nova Bold.otf']) {
      await (FontLoader('Proxima Nova')..addFont(rootBundle.load(asset))).load();
    }
  });

  for (final scale in <double>[0.5, 1, 2]) {
    testWidgets('Match accent keeps a 48px touch target beside Undo at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messenger = GlobalKey<ScaffoldMessengerState>();
      var matched = false;
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messenger,
          theme: kDarkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) => Theme(
                data: Theme.of(
                  context,
                ).copyWith(snackBarTheme: prismSnackBarThemeFor(context, Theme.of(context).snackBarTheme)),
                child: child!,
              ),
            ),
          ),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      final l10n = AppLocalizationsEn();
      reportWallpaperSetResult(
        null,
        WallpaperSetResult(
          WallpaperSetStatus.applied,
          'Wallpaper set successfully!',
          restore: <WallpaperRestore>[
            WallpaperRestore(
              WallpaperTarget.home,
              AppliedWallpaper(
                id: 'previous',
                source: 'prism',
                thumbnailUrl: '/previous.png',
                fullUrl: '/previous.png',
                target: 'home',
                appliedAt: DateTime.utc(2026),
              ),
            ),
          ],
        ),
        l10n: l10n,
        target: WallpaperTarget.home,
        messenger: messenger.currentState,
        onMatchAccent: () => matched = true,
        track: false,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final match = find.widgetWithText(TextButton, l10n.coreMatchAccent);
      final undo = find.widgetWithText(TextButton, l10n.coreUndo);
      for (final button in <Finder>[match, undo]) {
        final bounds = tester.getRect(button);
        expect(bounds.width, greaterThanOrEqualTo(kMinInteractiveDimension));
        expect(bounds.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      }
      final matchBounds = tester.getRect(match);
      expect(matchBounds.overlaps(tester.getRect(undo)), isFalse);
      await tester.tapAt(Offset(matchBounds.center.dx, matchBounds.bottom - 1));
      await tester.pumpAndSettle();
      expect(matched, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    });
  }
}
