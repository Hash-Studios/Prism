import 'dart:async';

import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) {
            captured = context;
            return const Scaffold();
          },
        ),
      ),
    );
    return captured;
  }

  setUp(() => IosWallpaperGuideSession.shown = false);

  void platformTest(String name, TargetPlatform platform, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  platformTest('shows three steps and an Open Photos button on iOS', TargetPlatform.iOS, (tester) async {
    final BuildContext context = await pumpHost(tester);

    unawaited(showIosSetWallpaperGuide(context));
    await tester.pumpAndSettle();

    expect(find.text('Open Photos.'), findsOneWidget);
    expect(find.text('Tap Share.'), findsOneWidget);
    expect(find.text('Tap Use as Wallpaper.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open Photos'), findsOneWidget);
  });

  final String autoStep = l10n.coreDepthEffectAutoLongTip;
  final String menuStep = l10n.coreDepthEffectMenuShortTip;

  for (final (WallDepthTier tier, String step) in <(WallDepthTier, String)>[
    (WallDepthTier.auto, autoStep),
    (WallDepthTier.menu, menuStep),
  ]) {
    platformTest('a ${tier.name} Depth Effect wall adds a fourth step', TargetPlatform.iOS, (tester) async {
      final BuildContext context = await pumpHost(tester);

      unawaited(showIosSetWallpaperGuide(context, depthTier: tier));
      await tester.pumpAndSettle();

      expect(find.text('Tap Use as Wallpaper.'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text(step), findsOneWidget);
    });
  }

  for (final WallDepthTier? tier in <WallDepthTier?>[WallDepthTier.none, null]) {
    platformTest('a wall with tier ${tier?.name} keeps the three steps', TargetPlatform.iOS, (tester) async {
      final BuildContext context = await pumpHost(tester);

      unawaited(showIosSetWallpaperGuide(context, depthTier: tier));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsNothing);
      expect(find.text(autoStep), findsNothing);
      expect(find.text(menuStep), findsNothing);
    });
  }

  platformTest('after the guide, the saved toast carries the Depth Effect step', TargetPlatform.iOS, (_) async {
    expect(savedWallpaperMessage(l10n: l10n, depthTier: WallDepthTier.menu), l10n.coreWallpaperSavedPhotos);

    IosWallpaperGuideSession.shown = true;

    expect(
      savedWallpaperMessage(l10n: l10n, depthTier: WallDepthTier.menu),
      l10n.coreWallpaperSavedWithTip(l10n.coreWallpaperSavedPhotos, l10n.coreDepthEffectMenuTip),
    );
    expect(
      savedWallpaperMessage(l10n: l10n, depthTier: WallDepthTier.auto),
      l10n.coreWallpaperSavedWithTip(l10n.coreWallpaperSavedPhotos, l10n.coreDepthEffectAutoTip),
    );
    expect(savedWallpaperMessage(l10n: l10n, depthTier: WallDepthTier.none), l10n.coreWallpaperSavedPhotos);
    expect(savedWallpaperMessage(l10n: l10n), l10n.coreWallpaperSavedPhotos);
  });

  platformTest('the saved message has no Depth Effect step on Android', TargetPlatform.android, (_) async {
    IosWallpaperGuideSession.shown = true;

    expect(savedWallpaperMessage(l10n: l10n, depthTier: WallDepthTier.menu), l10n.coreWallpaperDownloadedPictures);
  });

  platformTest('shows once per session', TargetPlatform.iOS, (tester) async {
    final BuildContext context = await pumpHost(tester);

    unawaited(showIosSetWallpaperGuide(context));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(IosWallpaperGuideSheet), findsNothing);

    unawaited(showIosSetWallpaperGuide(context));
    await tester.pumpAndSettle();
    expect(find.byType(IosWallpaperGuideSheet), findsNothing);
  });

  platformTest('does nothing on Android', TargetPlatform.android, (tester) async {
    final BuildContext context = await pumpHost(tester);

    unawaited(showIosSetWallpaperGuide(context));
    await tester.pumpAndSettle();
    expect(find.byType(IosWallpaperGuideSheet), findsNothing);
  });

  testWidgets('a denied Photos permission shows an Open settings action', (tester) async {
    final BuildContext context = await pumpHost(tester);

    showPhotosPermissionDenied(context);
    await tester.pump();

    expect(find.text('Open settings'), findsOneWidget);
  });

  test('only the denied code counts as a Photos permission problem', () {
    expect(isPhotosPermissionDenied('PHOTO_PERMISSION_DENIED'), isTrue);
    expect(isPhotosPermissionDenied('PHOTO_PERMISSION_RESTRICTED'), isFalse);
    expect(isPhotosPermissionDenied(null), isFalse);
  });
}
