import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/features/hints/views/feature_hint.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpOverlay(
  WidgetTester tester, {
  void Function(BuildContext context, ImageProvider? preview)? livePhotoAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClockOverlay(link: 'assets/images/prism.webp', file: false, livePhotoAction: livePhotoAction),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on iOS, the Live Photo button shows and tapping it calls the action once', (tester) async {
    int calls = 0;
    await _pumpOverlay(
      tester,
      livePhotoAction: (context, preview) {
        calls++;
      },
    );

    await tester.tap(find.byKey(const ValueKey<String>('set-screen-live-photo')));
    await tester.pump();

    expect(calls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on Android, the Live Photo button is not shown', (tester) async {
    await _pumpOverlay(tester, livePhotoAction: (context, preview) {});

    expect(find.byKey(const ValueKey<String>('set-screen-live-photo')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on iOS without a live photo action, the Live Photo button is not shown', (tester) async {
    await _pumpOverlay(tester);

    expect(find.byKey(const ValueKey<String>('set-screen-live-photo')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Live Photo button carries the livePhoto feature hint', (tester) async {
    await _pumpOverlay(tester, livePhotoAction: (context, preview) {});

    final Finder hint = find.ancestor(
      of: find.byKey(const ValueKey<String>('set-screen-live-photo')),
      matching: find.byWidgetPredicate((Widget w) => w is FeatureHint && w.id == HintId.livePhoto),
    );
    expect(hint, findsOneWidget);
    expect(tester.widget<FeatureHint>(hint).enabled, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on Android, no livePhoto feature hint is built', (tester) async {
    await _pumpOverlay(tester, livePhotoAction: (context, preview) {});

    expect(find.byWidgetPredicate((Widget w) => w is FeatureHint && w.id == HintId.livePhoto), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
