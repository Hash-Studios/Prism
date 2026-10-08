import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _slide = find.descendant(of: find.byType(ConnectivityWidget), matching: find.byType(SlideTransition));

void main() {
  testWidgets('rebuilds reuse the curve and disposal releases its listener', (tester) async {
    final key = GlobalKey();
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: true, key: key)),
      ),
    );
    await pump();
    final position = tester.widget<SlideTransition>(_slide).position;
    final curve = (position as AnimationWithParentMixin<double>).parent as CurvedAnimation;
    await pump();
    final rebuiltPosition = tester.widget<SlideTransition>(_slide).position;
    expect((rebuiltPosition as AnimationWithParentMixin<double>).parent, same(curve));
    await tester.pumpWidget(const SizedBox());
    expect(curve.isDisposed, isTrue);
  });

  testWidgets('enabling reduced motion settles an in-flight banner immediately', (tester) async {
    final key = GlobalKey();
    Future<void> pump(bool reduce) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(body: ConnectivityWidget(offline: true, key: key)),
        ),
      ),
    );
    await pump(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, greaterThan(0));
    await pump(true);
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('the banner slides in after a second while offline and stays', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget(offline: true))));
    expect(find.text('No internet connection'), findsOneWidget);
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);

    await tester.pump(const Duration(seconds: 30));
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
  });

  testWidgets('the banner hides on recovery and shows again when the connection drops', (tester) async {
    Future<void> pump({required bool offline}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: offline)),
      ),
    );

    await pump(offline: true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);

    await pump(offline: false);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);

    await pump(offline: true);
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
  });

  testWidgets('an online start never shows the banner', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget(offline: false))));
    await tester.pump(const Duration(seconds: 12));

    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);
  });

  testWidgets('leaving the screen before the timer fires cancels it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget(offline: true))));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    await tester.pump(const Duration(seconds: 12));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the banner is a live region only while it is shown', (tester) async {
    final handle = tester.ensureSemantics();
    Future<void> pump({required bool offline}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: offline)),
      ),
    );

    await pump(offline: true);
    expect(find.bySemanticsLabel('No internet connection'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('No internet connection')),
      isSemantics(label: 'No internet connection', isLiveRegion: true),
    );

    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });

  testWidgets('the banner says back online for two seconds, then leaves', (tester) async {
    Future<void> pump({required bool offline}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: offline)),
      ),
    );

    await pump(offline: true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await pump(offline: false);
    await tester.pumpAndSettle();
    expect(find.text('Back online'), findsOneWidget);
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);
  });

  testWidgets('dropping again while back online shows the offline message at once', (tester) async {
    Future<void> pump({required bool offline}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: offline)),
      ),
    );

    await pump(offline: true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await pump(offline: false);
    await tester.pump(const Duration(milliseconds: 500));
    await pump(offline: true);
    await tester.pumpAndSettle();

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Back online'), findsNothing);
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
  });

  testWidgets('recovering before the banner showed does not flash back online', (tester) async {
    Future<void> pump({required bool offline}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: offline)),
      ),
    );

    await pump(offline: true);
    await tester.pump(const Duration(milliseconds: 400));
    await pump(offline: false);
    await tester.pumpAndSettle();

    expect(find.text('Back online'), findsNothing);
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);
  });

  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    testWidgets('${option.label}: banner text is 12 sp and passes 4.5 in both states', (tester) async {
      Future<void> pump({required bool offline}) => tester.pumpWidget(
        MaterialApp(
          theme: option.theme,
          home: Scaffold(body: ConnectivityWidget(offline: offline)),
        ),
      );

      Future<void> expectReadable(String text) async {
        final Text label = tester.widget<Text>(find.text(text));
        final Color background = tester
            .widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)).first)
            .color!;
        expect(label.style!.fontSize, 12);
        expect(contrastRatio(label.style!.color!, background), greaterThanOrEqualTo(4.5), reason: text);
      }

      await pump(offline: true);
      await expectReadable('No internet connection');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await pump(offline: false);
      await expectReadable('Back online');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
