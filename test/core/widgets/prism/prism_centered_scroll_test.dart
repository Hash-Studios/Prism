import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Key content = Key('content');
  const Key action = Key('action');

  Future<void> pump(WidgetTester tester, double contentHeight) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: PrismPage(
          title: 'Title',
          body: PrismCenteredScroll(
            action: const SizedBox(height: 52, width: double.infinity, key: action),
            child: SizedBox(width: 200, height: contentHeight, key: content),
          ),
        ),
      ),
    );
    // Heights are measured after the first layout.
    await tester.pump();
  }

  testWidgets('a short message and its action form one centred group, 24 apart', (tester) async {
    await pump(tester, 200);

    final Rect area = tester.getRect(find.byType(PrismCenteredScroll));
    final Rect message = tester.getRect(find.byKey(content));
    final Rect button = tester.getRect(find.byKey(action));
    expect(button.top - message.bottom, 24);
    final double groupMiddle = (message.top + button.bottom) / 2;
    expect(groupMiddle, lessThan(area.center.dy), reason: 'the group sits a little above the middle');
    expect(groupMiddle, greaterThan(area.center.dy - 80));
    expect(area.bottom - button.bottom, greaterThan(100), reason: 'no action pinned at the very bottom');
  });

  testWidgets('long content scrolls and the action pins at the bottom', (tester) async {
    await pump(tester, 2000);

    expect(tester.takeException(), isNull);
    final Rect area = tester.getRect(find.byType(PrismCenteredScroll));
    final Rect button = tester.getRect(find.byKey(action));
    expect(area.bottom - button.bottom, lessThanOrEqualTo(40), reason: 'pinned clear of the bottom edge');
    final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).last);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pump();
    expect(tester.getRect(find.byKey(action)), button, reason: 'the pinned action does not scroll');
  });

  testWidgets('an action taller than the keyboard viewport scrolls with its content', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: const PrismPage(
          title: 'Title',
          body: PrismCenteredScroll(
            action: SizedBox(height: 300, key: action),
            child: SizedBox(height: 200, key: content),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).last);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    final Rect viewport = tester.getRect(find.byType(PrismCenteredScroll));
    expect(tester.getRect(find.byKey(action)).bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('the pinned action has a hairline only while content remains below', (tester) async {
    await pump(tester, 2000);
    await tester.pump();
    Color? borderColor() {
      final Finder boxes = find.ancestor(of: find.byKey(action), matching: find.byType(DecoratedBox));
      for (final DecoratedBox box in tester.widgetList<DecoratedBox>(boxes)) {
        final Decoration decoration = box.decoration;
        if (decoration is BoxDecoration && decoration.border is Border) {
          return (decoration.border! as Border).top.color;
        }
      }
      return null;
    }

    expect(borderColor(), kLightTheme.colorScheme.onSurface.withValues(alpha: 0.08));
    final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable).last);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(borderColor(), Colors.transparent);
  });
}
