---
name: prism-create-feature
description: Scaffold a new feature in the Prism Flutter app under `lib/features/<name>/`, following the layered structure used by wall_of_the_day, public_profile, personalized_feed, and user_search. This includes a Firestore-backed repository, a UseCase, an injectable BLoC with LoadStatus/ActionStatus, freezed events and states, an auto_route page, an analytics schema entry, and the matching test suite. Use this skill when the user says "create a new feature", "scaffold feature X", "add a feature called Y", or names a feature and asks to start it. Do not use this skill to add a page or widget to an existing feature, to edit shared infra (FirestoreClient, injection_module.dart, app_router.dart guards), or to build a tiny one-off toggle with no data flow. Those do not need the full stack.
---

# prism-create-feature

This skill generates a feature skeleton at `lib/features/<name>/`. The
skeleton matches Prism's current architecture. It is grounded in three
shipped features. Read them if anything below is unclear.

- `lib/features/wall_of_the_day/`. This is the smallest complete example: an
  entity, a repository, a use case, a bloc, one widget, no route. Use it as
  the template for the data, domain, and biz layers.
- `lib/features/public_profile/`. This feature has real `@RoutePage()`
  screens, registered in `lib/core/router/app_router.dart`. It uses a
  page-scoped `BlocProvider`.
- `lib/features/user_search/` and `lib/main.dart` (near the
  `MultiBlocProvider` in `runApp`). This shows the app-session-lived bloc
  pattern: the bloc is created once at app start, not per page.

Prism does not use Drift, SyncEngine, or go_router. Routing uses
`auto_route`. Persistence uses a `LocalStore` interface
(`lib/core/persistence/`), not a local database. Most features need no local
cache at all. The repository itself is the cache. See
`WallOfTheDayRepositoryImpl`: it holds three plain fields in memory, nothing
more.

## Inputs to confirm before generating

1. Feature name, snake_case. Example: `daily_challenge`.
2. Primary entity name, PascalCase. Example: `DailyChallenge`.
3. Data source: Firestore (most features), a `UseCase` wrapping another
   repository, or a plain remote or local call. This decides whether the
   feature needs a Firestore DTO or pointer class.
4. Does it need a route? A full-screen feature needs an `@RoutePage()` and an
   entry in `app_router.dart`. A card or widget embedded in an existing
   screen, like `WallOfTheDayCard` on the home feed, does not.
5. Bloc lifetime. Page-scoped means a fresh instance per visit, for example a
   profile screen keyed by user id. App-session-lived means the bloc is
   created once in `main.dart`'s `MultiBlocProvider` and stays alive for the
   whole session, for example search or feeds. Default to page-scoped unless
   the user says the state must survive navigating away and back.

If the user says "shape it like `wall_of_the_day`" or "like `public_profile`",
default everything from that feature. Only confirm the entity name and any
input that actually differs.

## Mental model

```
lib/features/<name>/
├── domain/
│   ├── entities/<name>_entity.dart          # plain class, or @freezed if it needs copyWith/equality
│   └── repositories/<name>_repository.dart  # abstract interface, returns Future<Result<T>>
│   └── usecases/<verb>_<name>_usecase.dart  # implements UseCase<Output, Params>
├── data/
│   ├── <name>_firestore_pointer.dart        # only if the Firestore doc shape needs parsing
│   └── repositories/<name>_repository_impl.dart  # @LazySingleton(as: <Name>Repository)
├── biz/bloc/
│   ├── <name>_bloc.j.dart                   # @injectable, part event/state/freezed
│   ├── <name>_event.j.dart                  # part of '<name>_bloc.j.dart'
│   └── <name>_state.j.dart                  # part of '<name>_bloc.j.dart'
├── views/
│   ├── pages/<name>_screen.dart             # @RoutePage() if it has its own route
│   └── widgets/<name>_card.dart             # if it is an embedded widget instead
└── <name>.dart                              # barrel: export the bloc, entity, and public widgets/pages
```

Not every feature needs every box. `wall_of_the_day` has no `views/pages/`
(it is a card, not a screen) and no route. `personalized_feed` has no
`data/<name>_firestore_pointer.dart` (it ranks feed items from other
repositories; it does not read Firestore directly). Generate only what the
feature needs. Do not pad the tree with empty files.

### State and status contract

Every bloc state carries a `LoadStatus` (`initial`, `loading`, `success`,
`failure`, from `lib/core/utils/status.dart`) for the main fetch. Add an
`ActionStatus` (`idle`, `inProgress`, `success`, `failure`) only when the
feature has a separate user-triggered action, such as follow, refresh-more,
or retry, that is distinct from the initial load. `wall_of_the_day` needs
only `LoadStatus`. `personalized_feed` needs both, because pull-to-refresh
and fetch-more sit on top of the initial load.

`Failure?` (from `lib/core/error/failure.dart`: `NetworkFailure`,
`ServerFailure`, `CacheFailure`, `ValidationFailure`, `UnknownFailure`) rides
in the state. This lets the UI show a message without a separate error
channel.

Every repository method returns `Future<Result<T>>`
(`lib/core/utils/result.dart`). It never throws across the domain boundary.
The bloc consumes it with `Result.fold(onSuccess: ..., onFailure: ...)`.

## Workflow

Use TodoWrite with one item per numbered step.

### 1. Confirm inputs and preconditions

Echo back the inputs. Read `lib/features/wall_of_the_day/` end to end once.
Every template below is lifted from it, or from `public_profile` or
`user_search` where noted. Do not start generating until the user confirms
the shape.

### 2. Generate files, in dependency order

1. `domain/entities/<name>_entity.dart`
2. `domain/repositories/<name>_repository.dart`
3. `data/<name>_firestore_pointer.dart` (Firestore features only)
4. `data/repositories/<name>_repository_impl.dart`
5. `domain/usecases/<verb>_<name>_usecase.dart`
6. `biz/bloc/<name>_event.j.dart`, `biz/bloc/<name>_state.j.dart`,
   `biz/bloc/<name>_bloc.j.dart`
7. `views/pages/<name>_screen.dart` (if routed) or
   `views/widgets/<name>_card.dart`
8. `lib/features/<name>/<name>.dart` barrel
9. `test/features/<name>/...` (see step 8 below)

### 3. Add the Firestore collection name (Firestore features only)

Add one constant to `lib/core/firestore/firestore_collections.dart`
(`FirebaseCollections`). Never use a string literal collection name anywhere
else. `firestore-guard` (step 8) fails on raw collection literals.

### 4. Register the route (routed features only)

In `lib/core/router/app_router.dart`:

- Add the import for the new `@RoutePage()` widget. Group it alphabetically
  with the other `package:Prism/features/...` imports.
- Add an `AutoRoute(path: '...', page: <Name>Route.page)` entry inside the
  right `routes:` list. Use the top-level list, or nest it under a tab's
  `children:` list. Match where similar features live: `public_profile`
  routes nest under the `profile` tab.
- Do not hand-write `app_router.gr.dart` or the `XRoute` class. Codegen
  produces both from the `@RoutePage()` annotation (step 6).

### 5. Wire the bloc into the widget tree

Pick one option, based on the lifetime decided in step 1.

Page-scoped is the default. It matches `public_profile`'s `ProfileScreen`.
Wrap the page's `build()` in `BlocProvider<<Name>Bloc>(create: (_) =>
getIt<<Name>Bloc>())`. This needs no change to `main.dart`.

App-session-lived matches `WotdBloc` and `UserSearchBloc`. Add one line to
the `MultiBlocProvider.providers` list in `lib/main.dart`'s `runApp(...)`
call, near the other feature blocs:

```dart
BlocProvider<<Name>Bloc>(create: (_) => getIt<<Name>Bloc>()..add(const <Name>Event.started())),
```

Either way, do not touch `lib/core/di/injection.config.dart` by hand. The
`@injectable` and `@LazySingleton` annotations, plus codegen (step 6),
produce the registration.

### 6. Add an analytics event (if the feature fires one)

Add an entry to `lib/core/analytics/schema/analytics_events.yaml`. See the
`wotd_viewed` and `wotd_opened` entries for the shape: `id`, then `fields:
[{name, key, type}]`. Never write an `AnalyticsEvent` subclass by hand. Run:

```sh
dart run tool/generate_analytics_schema.dart
fvm dart format --line-length 120 lib/core/analytics/events/generated/analytics_events.g.dart
```

This is exactly what `make analytics-gen` does. The generated class lands in
`lib/core/analytics/events/generated/analytics_events.g.dart`, and is
re-exported through `lib/core/analytics/events/events.dart`. Fire it with the
module-level `analytics` facade from `lib/analytics/analytics_service.dart`:
`analytics.track(<Name>ViewedEvent(...))`. Never call
`AnalyticsRuntime.instance` or `analytics.logEvent(...)` directly from
feature code. `analytics_raw_usage_guard.sh` forbids that outside
`lib/core/analytics/`.

### 7. Run codegen

```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --line-length 120 lib test
```

This is `make file-gen`. It regenerates `*.freezed.dart` for the bloc's event
and state, `injection.config.dart` for the new `@injectable` or
`@LazySingleton` bindings, and `app_router.gr.dart` for the new
`@RoutePage()`. One command covers all three. If codegen fails, fix the
annotated source file. Never hand-edit a `.g.dart`, `.freezed.dart`,
`.gr.dart`, or `.config.dart` output.

### 8. Run the guards and tests

```sh
fvm flutter analyze --no-pub --no-fatal-infos     # make analyze (CI mode)
fvm dart format --line-length 120 --set-exit-if-changed -o none lib test   # make format-check
./tool/firestore_guard.sh                          # only if the feature touches Firestore
./tool/no_dynamic_guard.sh
fvm flutter test test/features/<name>/
```

- `firestore_guard.sh` fails if any file outside `lib/core/firestore/` or
  `lib/core/di/injection_module.dart` imports `cloud_firestore`, calls
  `FirebaseFirestore.instance`, or uses a raw `.collection('...')` call or a
  string-literal collection name. Route all Firestore access through
  `FirestoreClient` and `FirebaseCollections`.
- `no_dynamic_guard.sh` fails on `dynamic`, `List<dynamic>`,
  `Map<dynamic, dynamic>`, or `as dynamic` in `lib/` or `test/`. Generated
  files are exempt.
- `no_shape_parse_guard.sh` only scans a fixed list of `data/` directories,
  set in `tool/no_shape_parse_guard.sh` (`wallhaven_feed`, `pexels_feed`,
  `prism_feed`, `public_profile`, `favourite_walls`). If the new
  feature's data layer hand-parses untyped JSON shapes (`is Map`, `is List`,
  `Object?` locals), add its `data/` path to that `TARGETS` array. It is not
  covered by default.
- `env_define_guard.sh` and `system_ui_guard.sh` matter only if the feature
  adds a `String.fromEnvironment` call (it must live in `lib/env/env.dart`)
  or sets `statusBarColor` or `systemNavigationBarColor` (it must go through
  the shared edge-to-edge overlay style). Most features touch neither.

If any command fails, fix the root cause. Do not report the feature done
until `analyze`, `format-check`, the relevant guards, and the new tests are
all green.

## Templates

`<name>` is the snake_case feature name. `<Name>` is the PascalCase entity or
feature name.

### `domain/entities/<name>_entity.dart`

Use a plain immutable class by default. This matches `WallOfTheDayEntity`.
Reach for `@freezed` (like `PublicProfileSetupEntity`) only when the bloc
needs `copyWith` or value equality on the entity itself, not just on the
bloc state.

```dart
class <Name>Entity {
  const <Name>Entity({
    required this.id,
    // ...user-supplied fields
  });

  final String id;
  // ...
}
```

### `domain/repositories/<name>_repository.dart`

```dart
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/<name>/domain/entities/<name>_entity.dart';

abstract class <Name>Repository {
  Future<Result<<Name>Entity?>> fetch<Name>();
}
```

### `data/<name>_firestore_pointer.dart`

Write this file only for a Firestore doc that needs manual field parsing.
Skip it if the DTO converters in `lib/core/firestore/converters/` already
cover the shape.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Payload shape for `<collection>/<docId>`.
class <Name>FirestorePointer {
  const <Name>FirestorePointer({required this.id /* ... */});

  factory <Name>FirestorePointer.fromMap(Map<String, dynamic> data) {
    final String id = data['id']?.toString() ?? '';
    return <Name>FirestorePointer(id: id);
  }

  final String id;
}
```

### `data/repositories/<name>_repository_impl.dart`

This is copied in shape from `WallOfTheDayRepositoryImpl`. Note the
`sourceTag` (used for Firestore telemetry, in the form
`<feature>.<method>.<what>`). A plain in-memory cache, three nullable fields,
is the norm. Do not add a local database for a single cached doc.

```dart
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/<name>/data/<name>_firestore_pointer.dart';
import 'package:Prism/features/<name>/domain/entities/<name>_entity.dart';
import 'package:Prism/features/<name>/domain/repositories/<name>_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: <Name>Repository)
class <Name>RepositoryImpl implements <Name>Repository {
  <Name>RepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;

  @override
  Future<Result<<Name>Entity?>> fetch<Name>() async {
    try {
      final <Name>FirestorePointer? doc = await _firestoreClient.getById<<Name>FirestorePointer>(
        FirebaseCollections.<name>,
        'current',
        (data, _) => <Name>FirestorePointer.fromMap(data),
        sourceTag: '<name>.fetch<Name>',
        preferCacheFirst: true,
      );
      if (doc == null) {
        return Result.success(null);
      }
      return Result.success(<Name>Entity(id: doc.id));
    } catch (e) {
      return Result.error(ServerFailure('Failed to fetch <Name>: $e'));
    }
  }
}
```

### `domain/usecases/fetch_<name>_usecase.dart`

```dart
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/<name>/domain/entities/<name>_entity.dart';
import 'package:Prism/features/<name>/domain/repositories/<name>_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class Fetch<Name>UseCase implements UseCase<<Name>Entity?, NoParams> {
  Fetch<Name>UseCase(this._repository);

  final <Name>Repository _repository;

  @override
  Future<Result<<Name>Entity?>> call(NoParams params) => _repository.fetch<Name>();
}
```

`UseCase<Output, Params>` and `NoParams` come from
`lib/core/usecase/usecase.dart`. If the call needs arguments, define a small
params class (see `FetchPersonalizedFeedRequest`) instead of adding optional
parameters to `call`.

### `biz/bloc/<name>_event.j.dart`

```dart
part of '<name>_bloc.j.dart';

@freezed
abstract class <Name>Event with _$<Name>Event {
  const factory <Name>Event.started() = _Started;
}
```

### `biz/bloc/<name>_state.j.dart`

```dart
part of '<name>_bloc.j.dart';

@freezed
abstract class <Name>State with _$<Name>State {
  const factory <Name>State({required LoadStatus status, <Name>Entity? entity, Failure? failure}) = _<Name>State;

  factory <Name>State.initial() => const <Name>State(status: LoadStatus.initial);
}
```

### `biz/bloc/<name>_bloc.j.dart`

```dart
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/<name>/domain/entities/<name>_entity.dart';
import 'package:Prism/features/<name>/domain/usecases/fetch_<name>_usecase.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part '<name>_event.j.dart';
part '<name>_state.j.dart';
part '<name>_bloc.j.freezed.dart';

@injectable
class <Name>Bloc extends Bloc<<Name>Event, <Name>State> {
  <Name>Bloc(this._fetch<Name>UseCase) : super(<Name>State.initial()) {
    on<_Started>(_onStarted);
  }

  final Fetch<Name>UseCase _fetch<Name>UseCase;

  Future<void> _onStarted(_Started event, Emitter<<Name>State> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));
    final result = await _fetch<Name>UseCase(const NoParams());
    result.fold(
      onSuccess: (entity) => emit(state.copyWith(status: LoadStatus.success, entity: entity, failure: null)),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
  }
}
```

If the feature has a second user action, such as refresh, follow, or
load-more, add an `ActionStatus actionStatus` field to the state (default
`ActionStatus.idle`) and a second event and handler. See
`PersonalizedFeedBloc._onFetchMoreRequested` for the shape: it bumps a page
counter, merges results, then re-emits.

### `views/pages/<name>_screen.dart` (routed feature)

```dart
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/<name>/biz/bloc/<name>_bloc.j.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class <Name>Screen extends StatelessWidget {
  const <Name>Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<<Name>Bloc>(
      create: (_) => getIt<<Name>Bloc>()..add(const <Name>Event.started()),
      child: Scaffold(
        body: BlocBuilder<<Name>Bloc, <Name>State>(
          builder: (context, state) {
            if (state.status == LoadStatus.loading || state.status == LoadStatus.initial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == LoadStatus.failure || state.entity == null) {
              return Center(child: Text(state.failure?.message ?? 'Something went wrong'));
            }
            return _<Name>Body(entity: state.entity!);
          },
        ),
      ),
    );
  }
}
```

### Route registration in `lib/core/router/app_router.dart`

```dart
import 'package:Prism/features/<name>/views/pages/<name>_screen.dart';
```

```dart
AutoRoute(path: '<route-from-user>', page: <Name>Route.page),
```

### `lib/features/<name>/<name>.dart` barrel

```dart
export 'biz/bloc/<name>_bloc.j.dart';
export 'domain/entities/<name>_entity.dart';
export 'views/pages/<name>_screen.dart';
```

### Tests

See the `prism-widget-test-harness` skill for the full diagnosis rubric. At
minimum, generate:

- `test/features/<name>/<name>_bloc_test.dart`. Use `bloc_test` and
  `mocktail`, and mock the use case. Mirror
  `test/features/ads/presentation/bloc/ads_bloc_test.dart`.
- `test/features/<name>/<name>_repository_impl_test.dart`. Mock
  `FirestoreClient`. Mirror an existing `*_repository_impl` test if a sibling
  feature has one, or write the same shape you would use against
  `WallOfTheDayRepositoryImpl`: mock `getById`, then assert the success, the
  null, and the failure branches.
- `test/features/<name>/<name>_screen_test.dart` (routed or widget features
  only). Use `MockBloc` and `BlocProvider.value`, following
  `test/features/wall_of_the_day/wall_of_the_day_card_test.dart`.

## Common pitfalls

- Hand-writing a Firestore collection string. Always add it to
  `FirebaseCollections` first. `firestore-guard` rejects literals.
- Calling `AnalyticsRuntime.instance` or `analytics.logEvent(...)` directly.
  Always go through a generated event class and the `analytics` facade.
- Editing `analytics_events.g.dart`, `injection.config.dart`, or
  `app_router.gr.dart` by hand. These are regenerated wholesale by `make
  file-gen` or `make analytics-gen`. Hand edits are lost, and they hide real
  drift from the guards (`analytics-check` diffs the generated file against a
  fresh regen).
- Adding a local Drift or sqflite table for a single cached value. Prism's
  norm for small cached docs is a few fields on the repository impl itself.
  See `WallOfTheDayRepositoryImpl._cachedEntity`. Reach for
  `lib/core/persistence/local_store.dart` only when the value must survive an
  app restart.
- Forgetting `ActionStatus` when a screen has both an initial load and a
  user action. Without it, a failed load-more looks identical to a failed
  initial load, and the UI cannot tell whether to show a retry button or a
  full error screen.
- Running `fvm flutter test` before codegen. The bloc's `part
  '<name>_bloc.j.freezed.dart'` does not exist yet. Run `make file-gen`
  first.
- Running `fvm flutter test` before `fvm flutter pub get` in a fresh
  worktree. `flutter test` crashes with `Bad state: No element` in
  `testCompilerBuildNativeAssets` when `.dart_tool/package_config.json` is
  missing. Run `pub get` once per worktree.

## When NOT to use this skill

- Adding a page or widget to an existing feature. Just write it in that
  feature's existing layers.
- A single settings toggle or a one-off screen with no data fetch. A small
  `Cubit`, or even a `StatefulWidget` with local state, is enough. The full
  entity, repository, and usecase stack is overkill.
- Changing shared infra (`FirestoreClient`, `injection_module.dart`,
  `app_router.dart` guards, `LocalStore`). That is a one-off edit, not a
  feature scaffold.
