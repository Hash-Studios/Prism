import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

void main() {
  testWidgets('the Recent searches header uses the secondary colour, not the labelLarge colour', (tester) async {
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

    expect(tester.widget<Text>(find.text('Recent searches')).style?.color, Colors.orange);
  });
}
