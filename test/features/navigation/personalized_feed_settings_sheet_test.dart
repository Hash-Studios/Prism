import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

const List<String> _names = <String>['Nature', 'Abstract', 'Space', 'Minimal', 'Cars'];

final List<PersonalizedInterest> _catalog = <PersonalizedInterest>[
  for (final String name in _names)
    PersonalizedInterest(name: name, query: name, imageUrl: '', sources: const <WallpaperSource>[]),
];

void main() {
  late TasteSignalStore store;
  List<String>? savedInterests;
  FeedMix? savedMix;

  setUp(() {
    store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    savedInterests = null;
    savedMix = null;
  });

  Future<void> pumpSheet(WidgetTester tester, {Set<String> initial = const <String>{'Nature', 'Abstract'}}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalizedFeedSettingsSheet(
            catalog: _catalog,
            initialInterests: initial,
            initialFeedMix: FeedMix.balanced,
            tasteSignals: store,
            onSave: (List<String> interests, FeedMix mix) async {
              savedInterests = interests;
              savedMix = mix;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));

  testWidgets('Save needs at least three interests', (tester) async {
    await pumpSheet(tester);
    expect(find.text('2 picked'), findsOneWidget);
    expect(find.text('Pick at least 3'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('Interest: Space, not selected'));
    await tester.pumpAndSettle();

    expect(find.text('3 picked'), findsOneWidget);
    expect(find.text('Pick at least 3'), findsNothing);
    expect(find.bySemanticsLabel('Interest: Space, selected'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('Save sends the chosen feed mix', (tester) async {
    await pumpSheet(tester, initial: <String>{'Nature', 'Abstract', 'Space'});

    await tester.ensureVisible(find.text('Adventurous'));
    await tester.tap(find.text('Adventurous'));
    await tester.pumpAndSettle();
    expect(find.text('More walls from outside your taste.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(savedMix, FeedMix.adventurous);
    expect(savedMix!.name, 'adventurous');
    expect(savedInterests, unorderedEquals(<String>['Nature', 'Abstract', 'Space']));
  });

  testWidgets('learned terms show until cleared', (tester) async {
    await store.record(TasteSignal(action: TasteAction.set, at: DateTime.now(), terms: const <String>['neon']));
    await pumpSheet(tester);

    expect(find.text('Neon'), findsOneWidget);
    expect(find.text('Open, save and set walls to teach your feed.'), findsNothing);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Neon'), findsNothing);
    expect(find.text('Open, save and set walls to teach your feed.'), findsOneWidget);
    expect(find.text('Learning history cleared'), findsOneWidget);
    expect(store.read(), isEmpty);
  });
}
