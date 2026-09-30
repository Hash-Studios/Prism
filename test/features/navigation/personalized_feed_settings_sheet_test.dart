// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockPersonalizedFeedBloc extends MockBloc<PersonalizedFeedEvent, PersonalizedFeedState>
    implements PersonalizedFeedBloc {}

class _MockSaveInterestsUseCase extends Mock implements SaveInterestsUseCase {}

class _FailingClearStore extends TasteSignalStore {
  _FailingClearStore(super.settingsLocal);

  @override
  Future<void> clear() async => throw StateError('disk full');
}

class _FakeFirebaseRemoteConfigPlatform extends FirebaseRemoteConfigPlatform {
  @override
  FirebaseRemoteConfigPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseRemoteConfigPlatform setInitialValues({required Map<Object?, Object?> remoteConfigValues}) => this;

  @override
  String getString(String key) => '';
}

/// Glint loops, so a screen that shows it never settles: pump a bounded time instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

const List<String> _names = <String>['Nature', 'Abstract', 'Space', 'Minimal', 'Cars'];

final List<PersonalizedInterest> _catalog = <PersonalizedInterest>[
  for (final String name in _names)
    PersonalizedInterest(name: name, query: name, imageUrl: '', sources: const <WallpaperSource>[]),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TasteSignalStore store;
  List<String>? savedInterests;
  FeedMix? savedMix;

  setUpAll(() async {
    registerFallbackValue(const SaveInterestsParams(interests: <String>[]));
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseRemoteConfigPlatform.instance = _FakeFirebaseRemoteConfigPlatform();
  });

  tearDown(() => toasts.overlayResolver = null);

  void showToastsInTree(WidgetTester tester) {
    toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);
  }

  setUp(() {
    personalizedFeedSettingsRevision.value = 0;
    store = TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore()));
    savedInterests = null;
    savedMix = null;
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    Size size = const Size(600, 844),
    Set<String> initial = const <String>{'Nature', 'Abstract'},
  }) async {
    tester.view.physicalSize = size;
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
              return true;
            },
          ),
        ),
      ),
    );
    showToastsInTree(tester);
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

  testWidgets('interest tiles expose their tap action to accessibility', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpSheet(tester, initial: <String>{'Nature', 'Abstract', 'Space'});

    expect(
      tester.getSemantics(find.bySemanticsLabel('Interest: Nature, selected')),
      isSemantics(label: 'Interest: Nature, selected', isButton: true, isSelected: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('failed save keeps the sheet open and re-enables Save', (tester) async {
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalizedFeedSettingsSheet(
            catalog: _catalog,
            initialInterests: const <String>{'Nature', 'Abstract', 'Space'},
            initialFeedMix: FeedMix.balanced,
            tasteSignals: store,
            onSave: (List<String> _, FeedMix _) async => false,
          ),
        ),
      ),
    );
    showToastsInTree(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Tune your feed'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.text('Could not save feed settings. Try again.'), findsOneWidget);
  });

  testWidgets('thrown save error also releases the saving state', (tester) async {
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalizedFeedSettingsSheet(
            catalog: _catalog,
            initialInterests: const <String>{'Nature', 'Abstract', 'Space'},
            initialFeedMix: FeedMix.balanced,
            tasteSignals: store,
            onSave: (_, _) async => throw StateError('save failed'),
          ),
        ),
      ),
    );
    showToastsInTree(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Tune your feed'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.text('Could not save feed settings. Try again.'), findsOneWidget);
  });

  testWidgets('remote save failure does not overwrite local interests', (tester) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    const List<String> previous = <String>['Nature', 'Abstract', 'Space'];
    await settings.set('onboarding_v2_interests', previous.join(','));
    final _MockSaveInterestsUseCase saveInterests = _MockSaveInterestsUseCase();
    when(() => saveInterests(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    getIt.registerSingleton<SaveInterestsUseCase>(saveInterests);
    app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = true;
    addTearDown(() async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(openPersonalizedFeedSettingsBottomSheet(context)),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.text('Tune your feed')))! as ModalBottomSheetRoute;
    expect(route.useSafeArea, isTrue);
    await tester.ensureVisible(find.bySemanticsLabel('Interest: Nature, selected'));
    await tester.tap(find.bySemanticsLabel('Interest: Nature, selected'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Interest: Aesthetic, not selected'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.bySemanticsLabel('Interest: Aesthetic, not selected'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(PersonalizedInterestsCatalog.selectedFromLocal(settings), previous);
    expect(find.text('Tune your feed'), findsOneWidget);
    expect(personalizedFeedSettingsRevision.value, 0);
    verify(() => saveInterests(any())).called(1);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('discovery uses the shared segmented control in ${brightness.name} mode', (tester) async {
      final ColorScheme scheme = ColorScheme.fromSeed(seedColor: const Color(0xff176b87), brightness: brightness);
      tester.view.physicalSize = const Size(600, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Scaffold(
            body: PersonalizedFeedSettingsSheet(
              catalog: _catalog,
              initialInterests: const <String>{'Nature', 'Abstract', 'Space'},
              initialFeedMix: FeedMix.balanced,
              tasteSignals: store,
              onSave: (_, _) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrismSegmented<FeedMix>), findsOneWidget);
      expect(find.text('Your taste, with a few surprises.'), findsOneWidget);
      await tester.ensureVisible(find.text('Familiar'));
      await tester.tap(find.text('Familiar'));
      await tester.pumpAndSettle();
      expect(find.text('Mostly what you already love.'), findsOneWidget);
    });
  }

  testWidgets('saving settings and clearing learning refresh an already-mounted feed', (tester) async {
    await store.record(TasteSignal(action: TasteAction.set, at: DateTime.now(), terms: const <String>['neon']));
    final _MockPersonalizedFeedBloc bloc = _MockPersonalizedFeedBloc();
    final PersonalizedFeedState failedState = PersonalizedFeedState.initial().copyWith(status: LoadStatus.failure);
    whenListen(bloc, const Stream<PersonalizedFeedState>.empty(), initialState: failedState);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<PersonalizedFeedBloc>(bloc);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await getIt.reset();
      personalizedFeedSettingsRevision.value = 0;
    });
    tester.view.physicalSize = const Size(600, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(child: PersonalizedFeedScreen(onTuneTap: () {})),
              Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PersonalizedFeedSettingsSheet(
                      catalog: _catalog,
                      initialInterests: const <String>{'Nature', 'Abstract', 'Space'},
                      initialFeedMix: FeedMix.balanced,
                      tasteSignals: store,
                      onSave: (_, _) async => true,
                    ),
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Open settings'));
    await _settle(tester);
    await tester.tap(find.text('Clear'));
    await _settle(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    verify(() => bloc.add(const PersonalizedFeedEvent.refreshRequested())).called(2);
  });

  testWidgets('settings sheet remains usable on a short screen with keyboard inset', (tester) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    const List<String> initial = <String>['Nature', 'Abstract', 'Space'];
    await settings.set('onboarding_v2_interests', initial.join(','));
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    app_state.prismUser = app_constants.createGuestPrismUser();
    addTearDown(() async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await getIt.reset();
    });
    tester.view.physicalSize = const Size(600, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(openPersonalizedFeedSettingsBottomSheet(context)),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final Finder save = find.widgetWithText(FilledButton, 'Save');
    expect(save, findsOneWidget);
    await tester.ensureVisible(save);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(348));
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tune your feed'), findsNothing);
    expect(PersonalizedInterestsCatalog.selectedFromLocal(settings), initial);
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

  testWidgets('a failed clear keeps the learned terms and says so', (tester) async {
    store = _FailingClearStore(SettingsLocalDataSource(InMemoryLocalStore()));
    await store.record(TasteSignal(action: TasteAction.set, at: DateTime.now(), terms: const <String>['neon']));
    await pumpSheet(tester);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Neon'), findsOneWidget);
    expect(find.text('Could not clear history. Try again.'), findsOneWidget);
    expect(find.text('Learning history cleared'), findsNothing);
  });
}
