import 'package:Prism/core/widgets/menu_button/pair_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PairCandidate _wall(String name) =>
    PairCandidate(fullUrl: '/nonexistent/$name.png', thumbnailUrl: '/nonexistent/$name.png');

void main() {
  Future<PairPick?> open(
    WidgetTester tester, {
    List<PairCandidate> favourites = const <PairCandidate>[],
    List<PairCandidate> history = const <PairCandidate>[],
    List<PairCandidate> downloads = const <PairCandidate>[],
    required Future<void> Function() act,
  }) async {
    PairPick? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showModalBottomSheet<PairPick>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    PairPickerSheet(favourites: favourites, history: history, loadDownloads: () async => downloads),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('has Favourites, Downloads and History tabs, and starts on Favourites', (tester) async {
    await open(tester, favourites: <PairCandidate>[_wall('a'), _wall('b')], act: () async {});

    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.bySemanticsLabel('Use this wallpaper for the lock screen'), findsNWidgets(2));
  });

  testWidgets('tapping a favourite closes the sheet with that pick', (tester) async {
    final PairPick? pick = await open(
      tester,
      favourites: <PairCandidate>[_wall('a'), _wall('b')],
      act: () => tester.tap(find.bySemanticsLabel('Use this wallpaper for the lock screen').last),
    );

    expect(pick?.source, PairSource.favourites);
    expect(pick?.candidate.fullUrl, '/nonexistent/b.png');
  });

  testWidgets('the Downloads tab loads the downloads list', (tester) async {
    final PairPick? pick = await open(
      tester,
      downloads: <PairCandidate>[_wall('d')],
      act: () async {
        await tester.tap(find.text('Downloads'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Use this wallpaper for the lock screen'));
      },
    );

    expect(pick?.source, PairSource.downloads);
    expect(pick?.candidate.fullUrl, '/nonexistent/d.png');
  });

  testWidgets('the History tab lists history walls', (tester) async {
    final PairPick? pick = await open(
      tester,
      history: <PairCandidate>[_wall('h')],
      act: () async {
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Use this wallpaper for the lock screen'));
      },
    );

    expect(pick?.source, PairSource.history);
  });

  testWidgets('an empty tab says so', (tester) async {
    await open(
      tester,
      act: () async {
        await tester.tap(find.text('Downloads'));
        await tester.pumpAndSettle();
      },
    );

    expect(find.text('No downloads yet.'), findsOneWidget);
  });
}
