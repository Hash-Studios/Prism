import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpTile(WidgetTester tester, Map<String, dynamic> payload, {bool rejected = false}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: WallTile(FirestoreDocument('S1', payload), rejected: rejected)),
      ),
    ),
  );
  tester.takeException();
}

void main() {
  const Map<String, dynamic> base = <String, dynamic>{
    'size': '2 MB',
    'resolution': '1440x3200',
    'wallpaper_url': 'https://example.com/w.jpg',
  };

  testWidgets('pads the minutes of the submission time', (tester) async {
    await _pumpTile(tester, <String, dynamic>{...base, 'createdAt': DateTime(2026, 3, 4, 17, 7)});

    expect(find.text('4 Mar 2026, 5:07 PM'), findsOneWidget);
  });

  testWidgets('shows no date when the submission time is missing', (tester) async {
    await _pumpTile(tester, base);

    expect(find.textContaining(RegExp(r'\d{4}, \d')), findsNothing);
    expect(find.text('1440 x 3200 · 2 MB'), findsOneWidget);
  });

  testWidgets(
    'shows the in review tag for a pending wallpaper and the rejected tag with its reason for a rejected one',
    (tester) async {
      await _pumpTile(tester, base);
      expect(find.text('In review'), findsOneWidget);
      expect(find.text('Why it was rejected'), findsNothing);

      await _pumpTile(tester, base, rejected: true);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Why it was rejected'), findsOneWidget);
    },
  );

  testWidgets('does not show the internal upload id', (tester) async {
    await _pumpTile(tester, base);

    expect(find.text('S1'), findsNothing);
  });

  testWidgets('labels download and delete actions for screen reader users', (tester) async {
    await _pumpTile(tester, base);

    final Iterable<String?> tooltips = find
        .byType(IconButton)
        .evaluate()
        .map((Element element) => (element.widget as IconButton).tooltip);
    expect(tooltips, containsAll(<String?>['Download wallpaper', 'Delete wallpaper']));
  });
}
