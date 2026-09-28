import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('back button exposes the platform back label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: HeadingChipBar(current: 'Downloads'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder back = find.byTooltip('Back');
    expect(back, findsOneWidget);
    expect(
      tester.getSemantics(back),
      matchesSemantics(
        tooltip: 'Back',
        isButton: true,
        isEnabled: true,
        isFocusable: true,
        hasEnabledState: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
  });
}
