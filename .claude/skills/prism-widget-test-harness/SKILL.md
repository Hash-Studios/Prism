---
name: prism-widget-test-harness
description: Write or debug bloc and widget tests in the Prism Flutter app using its real test patterns (mocktail, bloc_test, MockBloc, getIt, AnalyticsRuntime, Firebase platform-interface fakes). Use this skill for any test under `test/features/` or `test/core/`, and for failures involving getIt registration, timers or animations, network images, platform channels, or "Firebase not initialized". Prism has no shared pump-the-page helper. This skill documents the hand-rolled patterns the repo already uses instead. Not for CI/tooling scripts or non-Dart tests.
---

# Prism bloc and widget test harness

Prism has no `pump_feature_page.dart`-style shared harness. Every test wraps
its own `MaterialApp`, or skips the widget layer and tests the bloc alone.
Most feature tests in this repo are bloc tests, not widget tests, because the
bloc already isolates the UI from the network and from Firestore. Read
`test/features/wall_of_the_day/wall_of_the_day_card_test.dart` and
`test/features/ads/presentation/bloc/ads_bloc_test.dart` before writing a new
test. They are the two living references this skill is built from.

## The real patterns, by layer

### Bloc tests: mock the use case, not the repository or Firestore

Every bloc test in this repo (`ads_bloc_test.dart`, `startup_bloc_test.dart`,
`setups_bloc_test.dart`, `theme_light_bloc_test.dart`, and more) mocks the
`UseCase` the bloc depends on, with `mocktail`, and drives the bloc with
`bloc_test`'s `blocTest`. It never touches `FirebaseFirestore` or
`FirebaseAuth`. This is the reason Prism's bloc tests do not need Firebase
initialized: the domain boundary (`Result<T>` returned from a mocked
`UseCase.call`) sits between the bloc and anything that would need a real
platform channel.

```dart
class _MockFetch<Name>UseCase extends Mock implements Fetch<Name>UseCase {}

void main() {
  late _MockFetch<Name>UseCase useCase;

  setUp(() {
    useCase = _MockFetch<Name>UseCase();
    when(() => useCase(const NoParams())).thenAnswer(
      (_) async => Result.success(const <Name>Entity(id: 'abc')),
    );
  });

  blocTest<<Name>Bloc, <Name>State>(
    'emits success after started',
    build: () => <Name>Bloc(useCase),
    act: (bloc) => bloc.add(const <Name>Event.started()),
    expect: () => [
      <Name>State.initial().copyWith(status: LoadStatus.loading),
      <Name>State.initial().copyWith(status: LoadStatus.success, entity: const <Name>Entity(id: 'abc')),
    ],
  );
}
```

If a mocked method takes a non-primitive argument (a params object, a list),
call `registerFallbackValue(...)` in `setUpAll` before using `any()` for that
argument type. See `ads_bloc_test.dart`'s
`registerFallbackValue(const AddRewardParams(rewardAmount: 0))`.

### Widget tests: hand-rolled `MaterialApp` plus `MockBloc`

There is no shared pump helper. Build the widget tree by hand, and mock the
bloc with `MockBloc` from `bloc_test`, not with a real bloc wired to a mocked
use case. This keeps the widget test about rendering, not about business
logic (that belongs in the bloc test above).

```dart
class _MockXBloc extends MockBloc<XEvent, XState> implements XBloc {}

void main() {
  testWidgets('shows the loaded entity', (tester) async {
    final bloc = _MockXBloc();
    when(() => bloc.state).thenReturn(
      XState.initial().copyWith(status: LoadStatus.success, entity: const XEntity(id: 'abc')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<XBloc>.value(value: bloc, child: const XScreen()),
      ),
    );

    expect(find.text('abc'), findsOneWidget);
  });
}
```

`whenListen` (also from `bloc_test`) is the way to stub a stream of states
for a test that needs the widget to react to a state change, instead of
calling `bloc.emit` directly (emitting on a `MockBloc` does not flow through
`Cubit`/`Bloc` machinery the way a real bloc's `emit` would).

### Faking analytics

Do not write an inline fake `AppAnalytics`. Reuse
`test/support/fake_app_analytics.dart`'s `FakeAppAnalytics`, or subclass it
when a test needs to record calls:

```dart
class _RecordingAnalytics extends FakeAppAnalytics {
  final List<String> events = <String>[];

  @override
  Future<void> track(AnalyticsEvent event) async => events.add(event.eventName);
}
```

Install it by setting `AnalyticsRuntime.instance` directly (there is no DI
registration for analytics; the module-level `analytics` facade in
`lib/analytics/analytics_service.dart` reads `AnalyticsRuntime.instance`).
Always reset it in `addTearDown`:

```dart
final analytics = _RecordingAnalytics();
AnalyticsRuntime.instance = analytics;
addTearDown(AnalyticsRuntime.reset);
```

### Faking network images

Prism has no `network_image_mock` dependency and no `HttpOverrides` test
setup. The repo avoids the problem instead of mocking it: test fixtures pass
an empty string for `url`/`thumbnailUrl` fields, and `CachedNetworkImage`
never issues a request for an empty URL. See how
`wall_of_the_day_card_test.dart` constructs its `WallOfTheDayEntity` with
`url: ''` and `thumbnailUrl: ''`. Do the same for any entity fixture used in
a widget test: leave image URL fields empty unless the test is specifically
about image loading.

### Faking getIt registrations

Feature blocs are usually constructed directly in a test
(`<Name>Bloc(mockUseCase)`), which sidesteps `getIt` entirely. Register into
`getIt` only when the code under test resolves a dependency internally, the
way `OnboardingV2Bloc` reaches for `SettingsLocalDataSource` via app state
rather than a constructor argument:

```dart
getIt.registerSingleton<SettingsLocalDataSource>(settingsLocalDataSource);
```

Always pair a `getIt.registerSingleton` in `setUp` with `await getIt.reset()`
in `tearDown`. Leaked registrations from one test file bleed into the next
test file in the same run and cause "type X is already registered"
failures.

### Faking Firebase (only when the code under test calls a Firebase API directly)

Most bloc tests need no Firebase setup, because they mock at the `UseCase`
boundary. The one case that does need it: a bloc that reaches directly into
`FirebaseRemoteConfig.instance`, `FirebaseAuth.instance`, or similar, instead
of going through an injected abstraction. `test/features/onboarding_v2/onboarding_v2_bloc_resume_test.dart`
is the reference:

```dart
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart';

class _FakeFirebaseRemoteConfigPlatform extends FirebaseRemoteConfigPlatform {
  @override
  FirebaseRemoteConfigPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseRemoteConfigPlatform setInitialValues({required Map<dynamic, dynamic> remoteConfigValues}) => this;
  @override
  String getString(String key) => '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseRemoteConfigPlatform.instance = _FakeFirebaseRemoteConfigPlatform();
  });
  // ...
}
```

`setupFirebaseCoreMocks()` mocks `firebase_core`'s pigeon channel so
`Firebase.initializeApp()` succeeds without a real app. The
`_FakeFirebaseRemoteConfigPlatform` (or the equivalent for whichever Firebase
product the code touches) stands in for the actual platform channel. Add
`// ignore_for_file: depend_on_referenced_packages` at the top: the
`*_platform_interface` packages used here are transitive, not listed
directly in `pubspec.yaml`.

If you find yourself reaching for this pattern in a new bloc test, prefer
fixing the bloc to take the dependency through its constructor instead
(matching every other bloc in the repo). Reserve the Firebase-fake pattern
for existing code you cannot change as part of the current task.

### Resetting global mutable state

Two pieces of global state leak across tests if not reset:
`app_state.prismUser` (set by tests that sign a user in) and `getIt`. Always
reset both in `tearDown`:

```dart
tearDown(() async {
  app_state.prismUser = app_constants.createGuestPrismUser();
  await getIt.reset();
});
```

## Diagnosis rubric

Classify a failing test before touching feature code.

| # | Signature in the failure output | Class | Fix |
|---|---|---|---|
| 1 | `Object/factory with type X is not registered inside GetIt` | test-infra | Register the missing type in `setUp` with `getIt.registerSingleton`/`registerFactory`, and reset in `tearDown`. Check whether the bloc should take the dependency as a constructor argument instead; most Prism blocs do. |
| 2 | `type 'X' is already registered inside GetIt` | test-infra | A previous test in the same file (or a previous run in the same process) did not call `await getIt.reset()` in `tearDown`. Add it. |
| 3 | `Bad state: No element` from `testCompilerBuildNativeAssets` when running `flutter test` | environment | `.dart_tool/package_config.json` is missing, usually a fresh worktree. Run `fvm flutter pub get` once, then re-run the test. |
| 4 | `Error when reading 'lib/firebase_options.dart'` / `Undefined name 'DefaultFirebaseOptions'` at compile time, even for a test that has nothing to do with Firebase | environment | Something in the test's import chain reaches `lib/main.dart` (for example a router import that pulls in a screen that imports `main.dart` for a helper). `lib/firebase_options.dart` is gitignored and generated by `flutterfire configure`; without it, compilation fails. Create a local stub (`DefaultFirebaseOptions.currentPlatform` returning a placeholder `FirebaseOptions` per platform) and never commit it. |
| 5 | A snackbar, toast, or animated transition assertion fails right after the action that should trigger it | test-infra | These are async or animated. Call `await tester.pump()` for the frame that starts it, then `pump(const Duration(...))` for the animation. Avoid `pumpAndSettle` on anything with a repeating or infinite animation; it hangs. |
| 6 | `finder found 0 widgets` for something you know a `ListView` builds | test-infra | The list is lazy and the target is off-screen. Use `tester.ensureVisible(finder)` or `scrollUntilVisible` before asserting or tapping, or grow the surface with `tester.view.physicalSize` if the whole screen should fit. |
| 7 | State or VM mismatch, wrong text, wrong count, on a widget that IS visible and IS built | logic | Only now debug the feature. If the test reproduces a real defect, keep the test and fix the product code. |

The rule: work through classes 1 to 6 before deciding the product is broken.
Never "fix" product code to make a test-infra failure go away.

## Writing a new test (checklist)

1. Location mirrors `lib/`. `lib/features/<name>/biz/bloc/<name>_bloc.j.dart`
   maps to `test/features/<name>/<name>_bloc_test.dart`.
   `lib/features/<name>/views/pages/<name>_screen.dart` maps to
   `test/features/<name>/<name>_screen_test.dart`.
2. Default to a bloc test. Mock the `UseCase`(s) the bloc takes, with
   `mocktail`. Only add a widget test if the page has real conditional
   rendering worth asserting on (loading versus loaded versus error), the way
   `wall_of_the_day_card_test.dart` asserts an analytics side effect that
   only a widget test can observe (the impression dedupe across rebuilds).
3. For a widget test, mock the bloc with `MockBloc`, not a real bloc. Pass it
   in with `BlocProvider<X>.value(value: bloc, ...)`.
4. Leave image URL fields on test fixtures empty (`''`), unless the test is
   specifically about image loading.
5. Reset every piece of shared state you touched: `getIt.reset()`,
   `AnalyticsRuntime.reset()`, `app_state.prismUser`.
6. Run it with `fvm flutter test test/features/<name>/... --no-pub`. Run
   `fvm flutter pub get` first in a fresh worktree or a worktree that has
   never had `.dart_tool/` generated (see rubric row 3).
7. Run the full suite with `make test` (this is `fvm flutter test` under the
   hood) before calling the task done.

## Verified commands

These were run against this worktree while writing this skill:

```sh
fvm flutter pub get
fvm flutter test test/features/wall_of_the_day/wall_of_the_day_card_test.dart --no-pub
```

Both succeeded. The `pub get` step was required first: without it,
`.dart_tool/package_config.json` does not exist, and `flutter test` crashes
in `testCompilerBuildNativeAssets` with `Bad state: No element` (rubric row
3). After `pub get`, the test still failed to compile once, on
`lib/firebase_options.dart` missing (rubric row 4), because
`wall_of_the_day_card.dart` imports `app_router.dart`, which imports
`profile_screen.dart`, which imports `drawer_widget.dart`, which imports
`lib/main.dart` for a helper. A local, uncommitted stub of
`lib/firebase_options.dart` fixed it.

## Notes

- `mocktail`, not `mockito`, is the mocking library across this repo. Use
  `Mock`/`MockBloc` from `package:mocktail`, `when(() => ...)`, and
  `registerFallbackValue`.
- There is no golden-image testing set up in this repo. Do not introduce
  `golden_toolkit` or `matchesGoldenFile` for a new test unless the user asks
  for it specifically.
- `test/support/` currently has four files: `fake_app_analytics.dart`,
  `fake_error_reporter.dart`, `fake_user_block_repository.dart`, and
  `in_memory_local_store.dart`. Check there first before writing a new fake;
  a fake user-block repository or local store already exists.
