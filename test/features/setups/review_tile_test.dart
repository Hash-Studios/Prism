import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/setups/views/pages/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpTile(WidgetTester tester, Map<String, dynamic> payload, {bool rejected = false}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SetupTile(FirestoreDocument('S1', payload), false, rejected: rejected)),
      ),
    ),
  );
  tester.takeException();
}

void main() {
  const Map<String, dynamic> base = <String, dynamic>{
    'name': 'Dusk',
    'desc': 'Warm',
    'icon': 'Lawnicons',
    'icon_url': 'https://icons.app',
    'wallpaper_url': 'https://example.com/w.jpg',
  };

  testWidgets('pads the minutes of the submission time', (tester) async {
    await _pumpTile(tester, <String, dynamic>{...base, 'created_at': DateTime(2026, 3, 4, 17, 7)});

    expect(find.text('4 March 2026, 5:07 PM'), findsOneWidget);
  });

  testWidgets('shows no date when the submission time is missing', (tester) async {
    await _pumpTile(tester, base);

    expect(find.textContaining(RegExp(r'\d{4}, \d')), findsNothing);
    expect(find.text('S1'), findsOneWidget);
  });

  testWidgets('shows the in review chip for a pending setup and rejected chip for a rejected one', (tester) async {
    await _pumpTile(tester, base);
    expect(find.text('IN REVIEW'), findsOneWidget);

    await _pumpTile(tester, base, rejected: true);
    expect(find.text('REJECTED'), findsOneWidget);
  });
}
