import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/wall_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpTile(
  WidgetTester tester,
  Map<String, dynamic> payload, {
  ThemeData? theme,
  double textScale = 1,
  bool narrow = false,
  bool rejected = false,
}) async {
  tester.view.physicalSize = narrow ? const Size(320, 800) : const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: theme,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(child: WallTile(FirestoreDocument('S1', payload), rejected: rejected)),
          ),
        ),
      ),
    ),
  );
}

Finder _textStartingWith(String prefix) =>
    find.byWidgetPredicate((Widget widget) => widget is Text && (widget.data ?? '').startsWith(prefix));

void main() {
  const Map<String, dynamic> base = <String, dynamic>{
    'size': '2 MB',
    'resolution': '1440x3200',
    'wallpaper_url': 'https://example.com/w.jpg',
  };

  Map<String, dynamic> scheduled() => <String, dynamic>{
    ...base,
    'review': false,
    'releaseApprovedAt': DateTime.utc(2026, 11, 10),
    'releaseAt': DateTime.now().add(const Duration(days: 2)).toUtc(),
  };

  testWidgets('a rejected scheduled wall shows Rejected, never Releases', (tester) async {
    await _pumpTile(tester, scheduled(), rejected: true);

    expect(find.text('Rejected'), findsOneWidget);
    expect(_textStartingWith('Releases '), findsNothing);
  });

  testWidgets('a scheduled wall shows a Releases tag and not In review', (tester) async {
    await _pumpTile(tester, scheduled());

    expect(find.descendant(of: find.byType(PrismTag), matching: _textStartingWith('Releases ')), findsOneWidget);
    expect(find.text('In review'), findsNothing);
  });

  testWidgets('a pending wall with a release time shows In review and a Releases caption', (tester) async {
    await _pumpTile(tester, <String, dynamic>{
      ...base,
      'review': false,
      'releaseAt': DateTime.now().add(const Duration(days: 2)).toUtc(),
    });

    expect(find.text('In review'), findsOneWidget);
    expect(_textStartingWith('Releases '), findsOneWidget);
  });

  testWidgets('a pending wall without a release time shows In review and no Releases text', (tester) async {
    await _pumpTile(tester, <String, dynamic>{...base, 'review': false});

    expect(find.text('In review'), findsOneWidget);
    expect(_textStartingWith('Releases '), findsNothing);
  });

  testWidgets('a scheduled wall at large text and 320 px renders without an exception', (tester) async {
    await _pumpTile(tester, scheduled(), textScale: 2, narrow: true);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a scheduled wall shows its Releases tag in dark theme', (tester) async {
    await _pumpTile(tester, scheduled(), theme: ThemeData.dark());

    expect(_textStartingWith('Releases '), findsOneWidget);
  });
}
