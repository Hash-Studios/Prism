import 'dart:async';

import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
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
