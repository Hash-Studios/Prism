import 'package:Prism/features/library/views/widgets/offline_chip.dart';
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

  testWidgets('shows Offline at once when the first check finds no connection', (tester) async {
    await pumpChip(tester, FakeConnectivityService(online: false));

    expect(find.text('Offline'), findsOneWidget);
  });
}
