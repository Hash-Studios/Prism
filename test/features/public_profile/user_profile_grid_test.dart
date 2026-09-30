import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_grid.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

void main() {
  late _MockPublicProfileBloc bloc;

  setUp(() {
    bloc = _MockPublicProfileBloc();
  });

  Future<void> pumpGrid(WidgetTester tester, PublicProfileState state) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(value: bloc, child: const UserProfileGrid()),
        ),
      ),
    );
  }

  testWidgets('shows the empty illustration after a successful empty load', (tester) async {
    await pumpGrid(tester, PublicProfileState.initial().copyWith(status: LoadStatus.success));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('keeps every loaded wall and places See more in its own grid cell', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final walls = <PublicProfileWallEntity>[
        for (var index = 1; index <= 3; index++)
          PublicProfileWallEntity(id: 'wall-$index', by: 'Author $index', wallpaperUrl: 'https://example.com/$index'),
      ];
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(status: LoadStatus.success, walls: walls, hasMoreWalls: true),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect((grid.childrenDelegate as SliverChildBuilderDelegate).childCount, walls.length + 1);
      for (var index = 1; index <= walls.length; index++) {
        expect(find.bySemanticsLabel('Wallpaper by Author $index'), findsOneWidget);
      }
      expect(find.text('See more'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shows the final wall without See more when there is no next page', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final walls = <PublicProfileWallEntity>[
        for (var index = 1; index <= 3; index++)
          PublicProfileWallEntity(id: 'wall-$index', by: 'Author $index', wallpaperUrl: 'https://example.com/$index'),
      ];
      await pumpGrid(
        tester,
        PublicProfileState.initial().copyWith(status: LoadStatus.success, walls: walls, hasMoreWalls: false),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect((grid.childrenDelegate as SliverChildBuilderDelegate).childCount, walls.length);
      expect(find.text('See more'), findsNothing);
      expect(find.bySemanticsLabel('Wallpaper by Author 3'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
