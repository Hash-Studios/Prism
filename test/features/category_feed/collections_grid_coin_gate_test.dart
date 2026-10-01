import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as collections_data;
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _DelayedPreviewFirestore extends Fake implements FirestoreClient {
  final Completer<Map<String, dynamic>?> response = Completer<Map<String, dynamic>?>();
  int reads = 0;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    reads++;
    final Map<String, dynamic>? data = await response.future;
    return data == null ? null : map(data, id);
  }
}

void main() {
  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    CoinsService.instance.balanceNotifier.value = 0;
    collections_data.collections = <Map<String, dynamic>>[];
    await getIt.reset();
  });

  testWidgets('rapid premium collection taps issue only one preview check', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    collections_data.collections = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Premium', 'premium': true, 'thumb1': '', 'thumb2': ''},
    ];
    final _DelayedPreviewFirestore firestore = _DelayedPreviewFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
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
    final Finder tile = find.byType(InkWell).first;
    await tester.tap(tile);
    await tester.tap(tile);
    await tester.pump();

    expect(firestore.reads, 1);

    firestore.response.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Need ${CoinPolicy.premiumPreview24h} more coins.'), findsOneWidget);

    tester.widget<InkWell>(tile).onTap!();
    await tester.pump();
    expect(firestore.reads, 1);
    expect(find.textContaining('Need ${CoinPolicy.premiumPreview24h} more coins.'), findsOneWidget);

    Navigator.of(tester.element(tile)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(tile);
    await tester.pump();
    expect(firestore.reads, 2);
  });

  testWidgets('a failed preview check releases the tap guard after the prompt closes', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    collections_data.collections = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Premium', 'premium': true, 'thumb1': '', 'thumb2': ''},
    ];
    final _DelayedPreviewFirestore firestore = _DelayedPreviewFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
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

    final Finder tile = find.byType(InkWell).first;
    await tester.tap(tile);
    await tester.pump();
    firestore.response.completeError(StateError('preview lookup failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Need ${CoinPolicy.premiumPreview24h} more coins.'), findsOneWidget);

    Navigator.of(tester.element(tile)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(tile);
    await tester.pump();
    expect(firestore.reads, 2);
  });

  testWidgets('unmounting during preview check does not use a dead context', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    collections_data.collections = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Premium', 'premium': true, 'thumb1': '', 'thumb2': ''},
    ];
    final _DelayedPreviewFirestore firestore = _DelayedPreviewFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
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

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    firestore.response.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(firestore.reads, 1);
  });
}
