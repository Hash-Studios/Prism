import 'dart:async';

import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as collections_data;
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

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
  setUpAll(() => registerFallbackValue(CollectionViewRoute(collectionName: 'x')));

  setUp(() {
    // The coin gate asks for ad consent before it shows a prompt. The real flow needs the Google UMP plugin.
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => true,
      privacyOptionsRequired: () async => false,
      showPrivacyOptions: () async {},
    );
  });

  tearDown(() async {
    AdConsent.instance = AdConsent();
    app_state.prismUser = app_constants.createGuestPrismUser();
    CoinsService.instance.balanceNotifier.value = 0;
    CoinsService.instance.passesNotifier.value = Passes.empty;
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<CategoryFeedBloc>.value(
          value: bloc,
          child: const Scaffold(body: CollectionsGrid()),
        ),
      ),
    );
    final Finder tile = find.byType(CollectionCard).first;
    await tester.tap(tile);
    await tester.tap(tile);
    await tester.pump();

    expect(firestore.reads, 1);

    firestore.response.complete(null);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('You need ${CoinPolicy.premiumPreview24h} more.'), findsOneWidget);

    tester.widget<CollectionCard>(tile).onTap();
    await tester.pump();
    expect(firestore.reads, 1);
    expect(find.textContaining('You need ${CoinPolicy.premiumPreview24h} more.'), findsOneWidget);

    Navigator.of(tester.element(tile)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(tile);
    await tester.pump();
    expect(firestore.reads, 2);
  });

  for (final (int balance, bool offersVideo) in <(int, bool)>[(100, false), (0, true)]) {
    testWidgets('the preview sheet offers a video only when the balance is short (balance $balance)', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-1'
        ..loggedIn = true
        ..coins = balance;
      CoinsService.instance.balanceNotifier.value = balance;
      collections_data.collections = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Premium', 'premium': true, 'thumb1': '', 'thumb2': ''},
      ];
      final _DelayedPreviewFirestore firestore = _DelayedPreviewFirestore()..response.complete(null);
      getIt.registerSingleton<FirestoreClient>(firestore);
      final _MockCategoryFeedBloc bloc = _MockCategoryFeedBloc();
      when(() => bloc.state).thenReturn(CategoryFeedState.initial());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: BlocProvider<CategoryFeedBloc>.value(
            value: bloc,
            child: const Scaffold(body: CollectionsGrid()),
          ),
        ),
      );

      await tester.tap(find.byType(CollectionCard).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Unlock for 24 hours (-${CoinPolicy.premiumPreview24h})'), findsOneWidget);
      expect(find.textContaining('Watch ad for'), offersVideo ? findsOneWidget : findsNothing);
    });
  }

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<CategoryFeedBloc>.value(
          value: bloc,
          child: const Scaffold(body: CollectionsGrid()),
        ),
      ),
    );

    final Finder tile = find.byType(CollectionCard).first;
    await tester.tap(tile);
    await tester.pump();
    firestore.response.completeError(StateError('preview lookup failed'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('You need ${CoinPolicy.premiumPreview24h} more.'), findsOneWidget);

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<CategoryFeedBloc>.value(
          value: bloc,
          child: const Scaffold(body: CollectionsGrid()),
        ),
      ),
    );

    await tester.tap(find.byType(CollectionCard).first);
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(),
      ),
    );
    firestore.response.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(firestore.reads, 1);
  });

  testWidgets('an active premium pass opens a premium collection with no preview check or sheet', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
    CoinsService.instance.setPassesForTest(Passes(premiumPassUntil: DateTime.now().add(const Duration(hours: 5))));
    collections_data.collections = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Premium', 'premium': true, 'thumb1': '', 'thumb2': ''},
    ];
    final _DelayedPreviewFirestore firestore = _DelayedPreviewFirestore();
    getIt.registerSingleton<FirestoreClient>(firestore);
    final _MockCategoryFeedBloc bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(CategoryFeedState.initial());
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<CategoryFeedBloc>.value(
            value: bloc,
            child: const Scaffold(body: CollectionsGrid()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CollectionCard).first);
    await tester.pump();

    expect(firestore.reads, 0);
    expect(find.textContaining('Premium collection'), findsNothing);
    final CollectionViewRoute route = verify(() => router.push(captureAny())).captured.single as CollectionViewRoute;
    expect(route.args!.collectionName, 'premium');
  });
}
