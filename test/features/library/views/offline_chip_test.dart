import 'package:Prism/features/library/views/widgets/offline_chip.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_connectivity_service.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, FakeConnectivityService service) async {
    addTearDown(service.controller.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OfflineChip(connectivity: service)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows nothing while online', (tester) async {
    await pumpChip(tester, FakeConnectivityService());

    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('shows Offline when the connection drops and hides it when it returns', (tester) async {
    final FakeConnectivityService service = FakeConnectivityService();
    await pumpChip(tester, service);

    service.controller.add(false);
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline'), findsOneWidget);

    service.controller.add(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('is a 36 px pill with the app chip fill and label colour', (tester) async {
    final PrismThemeOption frost = prismLightThemes.first;
    final ThemeData theme = withPrismAccent(frost.theme, frost.defaultAccentValue);
    final FakeConnectivityService service = FakeConnectivityService(online: false);
    addTearDown(service.controller.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(child: OfflineChip(connectivity: service)),
        ),
      ),
    );
    await tester.pump();

    final Ink ink = tester.widget<Ink>(find.descendant(of: find.byType(Chip), matching: find.byType(Ink)));
    final ShapeDecoration decoration = ink.decoration! as ShapeDecoration;
    final Color label = tester
        .widget<RichText>(find.descendant(of: find.text('Offline'), matching: find.byType(RichText)))
        .text
        .style!
        .color!;

    expect(decoration.shape, isA<StadiumBorder>());
    expect(decoration.color, theme.colorScheme.secondary.withValues(alpha: 0.08));
    expect(label, theme.colorScheme.secondary);
    expect(tester.getSize(find.descendant(of: find.byType(Chip), matching: find.byType(Ink))).height, 36);
  });

  testWidgets('shows Offline at once when the first check finds no connection', (tester) async {
    await pumpChip(tester, FakeConnectivityService(online: false));

    expect(find.text('Offline'), findsOneWidget);
  });
}
