import 'dart:async';

import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
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

  const String autoStep =
      'Depth Effect turns on by itself. On iOS\u00A018 or older, keep widgets off the space under the clock.';
  const String menuStep = 'Tap ••• then Depth\u00A0Effect.';

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
    expect(savedWallpaperMessage(depthTier: WallDepthTier.menu), 'Saved to Photos.');

    IosWallpaperGuideSession.shown = true;

    expect(
      savedWallpaperMessage(depthTier: WallDepthTier.menu),
      'Saved to Photos. In the Lock Screen editor, tap ••• then Depth\u00A0Effect.',
    );
    expect(savedWallpaperMessage(depthTier: WallDepthTier.auto), 'Saved to Photos. Depth Effect turns on by itself.');
    expect(savedWallpaperMessage(depthTier: WallDepthTier.none), 'Saved to Photos.');
    expect(savedWallpaperMessage(), 'Saved to Photos.');
  });

  platformTest('the saved message has no Depth Effect step on Android', TargetPlatform.android, (_) async {
    IosWallpaperGuideSession.shown = true;

    expect(savedWallpaperMessage(depthTier: WallDepthTier.menu), 'Wall downloaded in Pictures/Prism!');
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
