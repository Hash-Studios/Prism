import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the banner slides in after a second and out after ten', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget())));
    expect(find.text('No Internet'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 12));

    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the screen before the timers fire cancels them', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget())));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    await tester.pump(const Duration(seconds: 12));

    expect(tester.takeException(), isNull);
  });
}
