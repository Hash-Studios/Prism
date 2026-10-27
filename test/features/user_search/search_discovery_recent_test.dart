import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/views/widgets/palette_swatch.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

void main() {
  testWidgets('the Recent searches header keeps its own colour, not the labelLarge colour', (tester) async {
    const state = SearchDiscoveryState(status: LoadStatus.success, trendingWalls: []);
    final bloc = _MockSearchDiscoveryBloc();
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
    final ThemeData theme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(secondary: Colors.orange),
      textTheme: ThemeData.dark().textTheme.copyWith(labelLarge: const TextStyle(color: Colors.black)),
    );
    await tester.pumpWidget(
      BlocProvider<SearchDiscoveryBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: theme,
          home: Scaffold(
            body: SearchDiscoveryWidget(
              tags: const <String>[],
              selectedTag: '',
              onTagPressed: (_) {},
              recentSearches: const <String>['space'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text('Recent searches')).style?.color, isNot(Colors.black));
  });

  group('Browse by colour', () {
    Future<void> pumpDiscovery(WidgetTester tester, {void Function(PrismPaletteColor)? onColorPressed}) async {
      const state = SearchDiscoveryState(status: LoadStatus.success, trendingWalls: []);
      final bloc = _MockSearchDiscoveryBloc();
      when(() => bloc.state).thenReturn(state);
      whenListen(bloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
      await tester.pumpWidget(
        BlocProvider<SearchDiscoveryBloc>.value(
          value: bloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,

            home: Scaffold(
              body: SearchDiscoveryWidget(
                tags: const <String>[],
                selectedTag: '',
                onTagPressed: (_) {},
                onColorPressed: onColorPressed,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('lists the twelve palette colours as labelled swatches', (tester) async {
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDiscovery(tester, onColorPressed: (_) {});

      expect(find.text('Browse by colour'), findsOneWidget);
      expect(tester.widgetList<PaletteSwatch>(find.byType(PaletteSwatch)).map((s) => s.color.id), <String>[
        for (final PrismPaletteColor entry in prismPalette) entry.id,
      ]);
      expect(find.bySemanticsLabel('Red'), findsOneWidget);
      expect(find.bySemanticsLabel('White'), findsOneWidget);
    });

    testWidgets('tapping a swatch reports that palette colour', (tester) async {
      final List<String> picked = <String>[];
      await pumpDiscovery(tester, onColorPressed: (color) => picked.add(color.id));

      await tester.tap(find.bySemanticsLabel('Orange'));
      await tester.pump();

      expect(picked, <String>['orange']);
    });

    testWidgets('the section is hidden without a handler', (tester) async {
      await pumpDiscovery(tester);

      expect(find.text('Browse by colour'), findsNothing);
      expect(find.byType(PaletteSwatch), findsNothing);
    });
  });

  Future<void> pumpDiscovery(
    WidgetTester tester, {
    VoidCallback? onDepthPressed,
    VoidCallback? onSpatialPressed,
  }) async {
    const state = SearchDiscoveryState(status: LoadStatus.success, trendingWalls: []);
    final bloc = _MockSearchDiscoveryBloc();
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
    await tester.pumpWidget(
      BlocProvider<SearchDiscoveryBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: SearchDiscoveryWidget(
              tags: const <String>[],
              selectedTag: '',
              onTagPressed: (_) {},
              onColorPressed: (_) {},
              onDepthPressed: onDepthPressed,
              onSpatialPressed: onSpatialPressed,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('Depth Effect row', () {
    testWidgets('shows above Browse by colour and calls the handler on tap', (tester) async {
      int taps = 0;
      await pumpDiscovery(tester, onDepthPressed: () => taps++);

      expect(find.text('Depth Effect'), findsOneWidget);
      expect(find.text('Subject in front of the clock'), findsOneWidget);
      expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Depth Effect, subject in front of the clock'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Depth Effect')).dy,
        lessThan(tester.getTopLeft(find.text('Browse by colour')).dy),
      );

      await tester.tap(find.text('Depth Effect'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('is absent without a handler', (tester) async {
      await pumpDiscovery(tester);

      expect(find.text('Depth Effect'), findsNothing);
      expect(find.byIcon(Icons.layers_rounded), findsNothing);
      expect(find.text('Find creators'), findsOneWidget);
    });
  });

  group('Spatial Scene row', () {
    testWidgets('shows below the Depth Effect row and calls the handler on tap', (tester) async {
      int taps = 0;
      await pumpDiscovery(tester, onDepthPressed: () {}, onSpatialPressed: () => taps++);

      expect(find.text('Spatial'), findsOneWidget);
      expect(find.text('Walls with clear 3D depth'), findsOneWidget);
      expect(find.byIcon(Icons.view_in_ar_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Spatial, walls with clear 3D depth'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Spatial')).dy, greaterThan(tester.getTopLeft(find.text('Depth Effect')).dy));

      await tester.tap(find.text('Spatial'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('is absent without a handler', (tester) async {
      await pumpDiscovery(tester);

      expect(find.text('Spatial'), findsNothing);
      expect(find.byIcon(Icons.view_in_ar_rounded), findsNothing);
      expect(find.text('Find creators'), findsOneWidget);
    });
  });
}
