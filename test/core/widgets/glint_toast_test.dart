import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({bool reduce = false, required Widget child}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('shows Glint, then removes it', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      host(
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    showGlintToast(ctx);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Glint), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Glint), findsNothing);
  });

  testWidgets('shows nothing under reduce motion', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      host(
        reduce: true,
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    showGlintToast(ctx);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Glint), findsNothing);
  });

  testWidgets('FavoriteIcon reports the toggle on tap', (tester) async {
    int changes = 0;
    await tester.pumpWidget(
      host(
        child: Center(child: FavoriteIcon(valueChanged: () => changes++)),
      ),
    );
    await tester.tap(find.byType(FavoriteIcon));
    expect(changes, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('FavoriteIcon settles its pop when reduce motion changes', (tester) async {
    final Widget favorite = Center(child: FavoriteIcon(valueChanged: () {}));
    await tester.pumpWidget(host(child: favorite));
    await tester.tap(find.byType(FavoriteIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final Finder scale = find.descendant(of: find.byType(FavoriteIcon), matching: find.byType(ScaleTransition));
    expect(tester.widget<ScaleTransition>(scale).scale.value, greaterThan(1));

    await tester.pumpWidget(host(reduce: true, child: favorite));
    expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('hides an active toast when the system enables reduce motion', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    showGlintToast(context);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(Glint), findsOneWidget);

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(find.byType(Glint), findsNothing);
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });
}
