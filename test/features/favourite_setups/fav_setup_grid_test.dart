import 'package:Prism/features/favourite_setups/biz/bloc/favourite_setups_bloc.j.dart';
import 'package:Prism/features/favourite_setups/views/widgets/fav_setup_grid.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFavouriteSetupsBloc extends MockBloc<FavouriteSetupsEvent, FavouriteSetupsState>
    implements FavouriteSetupsBloc {}

void main() {
  testWidgets('favourite setup loading cards have rounded corners', (tester) async {
    final bloc = _MockFavouriteSetupsBloc();
    when(() => bloc.state).thenReturn(FavouriteSetupsState.initial());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<FavouriteSetupsBloc>.value(value: bloc, child: const FavouriteSetupGrid()),
        ),
      ),
    );
    await tester.pump();

    final tile = find.descendant(of: find.byType(GridView), matching: find.byType(DecoratedBox)).first;
    final decoration = tester.widget<DecoratedBox>(tile).decoration as BoxDecoration;

    expect(decoration.borderRadius, BorderRadius.circular(20));
  });
}
