import 'package:Prism/data/collections/provider/collections_without_provider.dart' as collections_data;
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

void main() {
  tearDown(() => collections_data.collections = <Map<String, dynamic>>[]);

  testWidgets('a tile decodes by height only, so the photo keeps its shape', (tester) async {
    collections_data.collections = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Space', 'thumb1': 'https://example.test/space.jpg', 'thumb2': ''},
    ];
    final _MockCategoryFeedBloc bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(CategoryFeedState.initial());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CategoryFeedBloc>.value(
          value: bloc,
          child: Scaffold(body: CollectionsGrid()),
        ),
      ),
    );

    final ResizeImage image = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(image.width, isNull);
    expect(image.height, isNotNull);
    // The photo fails to load in tests. The load error is not what this test checks.
    tester.takeException();
  });
}
