import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/l10n/generated/app_localizations_de.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/generated/app_localizations_es.dart';
import 'package:Prism/l10n/generated/app_localizations_id.dart';
import 'package:Prism/l10n/generated/app_localizations_pt.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeTabsRouter extends ChangeNotifier implements TabsRouter {
  @override
  int get activeIndex => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Prism has no Russian strings yet. This stands in for a long Cyrillic translation.
class _LongRu extends AppLocalizationsEn {
  @override
  String get coreWallpaperSet => 'Обои установлены на главный экран и на экран блокировки вашего телефона';

  @override
  String get coreUndo => 'Отменить';

  @override
  String get coreMatchAccent => 'Подобрать акцентный цвет';
}

final Map<String, AppLocalizations> _locales = <String, AppLocalizations>{
  'pt-BR': AppLocalizationsPtBr(),
  'de': AppLocalizationsDe(),
  'es': AppLocalizationsEs(),
  'id': AppLocalizationsId(),
  'en': AppLocalizationsEn(),
  'ru (long)': _LongRu(),
};

WallpaperSetResult _successWithUndo() => WallpaperSetResult(
  WallpaperSetStatus.applied,
  'Wallpaper set successfully!',
  restore: <WallpaperRestore>[
    WallpaperRestore(
      WallpaperTarget.home,
      AppliedWallpaper(
        id: '1',
        source: 'prism',
        thumbnailUrl: '/prev.png',
        fullUrl: '/prev.png',
        target: 'home',
        appliedAt: DateTime.utc(2026),
      ),
    ),
  ],
);

Future<void> _loadFonts() async {
  for (final String asset in <String>['assets/fonts/ProximaNova-Regular.otf', 'assets/fonts/Proxima Nova Bold.otf']) {
    await (FontLoader('Proxima Nova')..addFont(rootBundle.load(asset))).load();
  }
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  Future<void> showOnFeed(
    WidgetTester tester,
    AppLocalizations l10n, {
    required double textScale,
    required bool matchAccent,
    required VoidCallback onMatchAccent,
  }) async {
    tester.view
      ..devicePixelRatio = 2.625
      ..physicalSize = const Size(1080, 2400)
      ..viewPadding = const FakeViewPadding(top: 63, bottom: 63)
      ..padding = const FakeViewPadding(top: 63, bottom: 63);
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 30));
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
          child: Builder(
            builder: (context) {
              final ThemeData theme = Theme.of(context);
              return Theme(
                data: theme.copyWith(snackBarTheme: prismSnackBarThemeFor(context, theme.snackBarTheme)),
                child: child!,
              );
            },
          ),
        ),
        home: TabsRouterScope(
          controller: _FakeTabsRouter(),
          stateHash: 0,
          child: BottomBar(
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => reportWallpaperSetResult(
                      context,
                      _successWithUndo(),
                      l10n: l10n,
                      target: WallpaperTarget.home,
                      onMatchAccent: matchAccent ? onMatchAccent : null,
                      track: false,
                    ),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  for (final MapEntry<String, AppLocalizations>(key: String locale, value: AppLocalizations l10n) in _locales.entries) {
    for (final double textScale in <double>[1.0, 1.3, 2.0]) {
      for (final bool matchAccent in <bool>[true, false]) {
        testWidgets('$locale at text scale $textScale${matchAccent ? ' with Match accent' : ''}: '
            'the message gets room, stays within 2 lines, and the snackbar clears the nav', (tester) async {
          var matchCalls = 0;
          await showOnFeed(
            tester,
            l10n,
            textScale: textScale,
            matchAccent: matchAccent,
            onMatchAccent: () => matchCalls++,
          );

          expect(tester.takeException(), isNull);
          final Rect card = tester.getRect(
            find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first,
          );
          final RenderParagraph message = tester.renderObject<RenderParagraph>(find.text(l10n.coreWallpaperSet));
          expect(message.constraints.maxWidth, greaterThan(card.width / 2), reason: 'message squeezed');

          final TextPainter oneLine = TextPainter(
            text: message.text,
            textScaler: message.textScaler,
            textDirection: TextDirection.ltr,
          )..layout();
          expect(message.size.height, lessThanOrEqualTo(oneLine.height * 2 + 0.5), reason: 'more than 2 lines');
          oneLine.dispose();

          final Rect undo = tester.getRect(find.widgetWithText(TextButton, l10n.coreUndo));
          expect(undo.right, greaterThan(card.center.dx), reason: 'Undo is not on the right');
          expect(card.inflate(0.5).contains(undo.topLeft) && card.inflate(0.5).contains(undo.bottomRight), isTrue);
          expect(undo.size.shortestSide, greaterThanOrEqualTo(kMinInteractiveDimension));
          final Rect nav = tester.getRect(find.byType(PrismBottomNav));
          expect(card.bottom, lessThanOrEqualTo(nav.top - 8), reason: 'snackbar overlaps the bottom nav');
          final Finder matchButton = find.widgetWithText(TextButton, l10n.coreMatchAccent);
          if (matchAccent) {
            final Rect match = tester.getRect(matchButton);
            expect(card.inflate(0.5).contains(match.topLeft) && card.inflate(0.5).contains(match.bottomRight), isTrue);
            expect(match.size.shortestSide, greaterThanOrEqualTo(kMinInteractiveDimension));
            await tester.tap(matchButton);
            await tester.pumpAndSettle();
            expect(matchCalls, 1);
            expect(find.byType(SnackBar), findsNothing);
          } else {
            expect(matchButton, findsNothing);
            expect(matchCalls, 0);
          }
        });
      }
    }
  }
}
