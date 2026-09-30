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
}
