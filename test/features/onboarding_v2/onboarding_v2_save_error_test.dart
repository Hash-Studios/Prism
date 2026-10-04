import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:Prism/main.dart' as app_main;
// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/analysis/utilities.dart';
// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

class _FailingSetLocalStore extends InMemoryLocalStore {
  @override
  Future<void> set(String key, Object? value) => Future<void>.error(StateError('offline'));
}

class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount, required this.child});

  final VoidCallback onMount;
  final Widget child;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth({this.user, this.signOutError});

  User? user;
  final Object? signOutError;

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    if (signOutError != null) throw signOutError!;
    user = null;
  }
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';

  @override
  String? get email => 'user@example.com';
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeFirestore extends Fake implements FirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) => Future<T?>.error(StateError('offline'));

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) =>
      Future<void>.error(StateError('offline'));
}

class _FakeMessaging extends Fake implements FirebaseMessaging {}

OnboardingStarterCreatorEntity _creator(int i) => OnboardingStarterCreatorEntity(
  userId: 'creator-$i',
  email: 'creator-$i@example.com',
  name: 'Creator $i',
  photoUrl: '',
  previewUrls: const <String>[],
  rank: i,
  followerCount: 0,
);

final OnboardingV2State _interests = OnboardingV2State.initial().copyWith(
  step: OnboardingV2Step.interests,
  loadStatus: LoadStatus.success,
  interestsData: OnboardingInterestsData.initial().copyWith(
    available: const <String>['Abstract', 'Nature', 'Space'],
    selected: const <String>['Abstract', 'Nature', 'Space'],
  ),
);

final OnboardingV2State _starterPack = _interests.copyWith(
  step: OnboardingV2Step.starterPack,
  starterPackData: OnboardingStarterPackData(
    creators: <OnboardingStarterCreatorEntity>[_creator(1), _creator(2), _creator(3)],
    selectedEmails: <String>{'creator-1@example.com', 'creator-2@example.com', 'creator-3@example.com'},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> toasts = <String>[];

  setUp(() {
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    await getIt.reset();
  });

  Future<_MockOnboardingBloc> pumpShell(
    WidgetTester tester,
    OnboardingV2State from,
    OnboardingV2State to, {
    SettingsLocalDataSource? settings,
    Future<bool> Function()? signOutForRecovery,
    VoidCallback? onMount,
    Stream<OnboardingV2State>? states,
  }) async {
    final _MockOnboardingBloc bloc = _MockOnboardingBloc();
    whenListen(bloc, states ?? Stream<OnboardingV2State>.value(to), initialState: from);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<OnboardingV2Bloc>(bloc);
    getIt.registerSingleton<SettingsLocalDataSource>(settings ?? SettingsLocalDataSource(InMemoryLocalStore()));

    await tester.pumpWidget(
      app_main.RestartWidget(
        child: MaterialApp(
          home: _MountCounter(
            onMount: onMount ?? () {},
            child: OnboardingV2Shell(signOutForRecovery: signOutForRecovery),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return bloc;
  }

  testWidgets('a failed interests save shows an error and a retry', (tester) async {
    await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(actionStatus: ActionStatus.failure),
    );

    expect(toasts, <String>["Couldn't save your picks. Try again."]);
    expect(find.text('try again'), findsOneWidget);
    expect(find.textContaining("couldn't save your picks"), findsOneWidget);
  });

  test('the shell route annotation belongs to the shell class', () {
    final unit = parseString(
      content: File('lib/features/onboarding_v2/src/views/onboarding_v2_shell.dart').readAsStringSync(),
    ).unit;
    final shell = unit.declarations.whereType<ClassDeclaration>().firstWhere(
      (declaration) => declaration.namePart.typeName.lexeme == 'OnboardingV2Shell',
    );

    expect(shell.metadata.single.toSource(), startsWith('@RoutePage'));
  });

  testWidgets('a failed starter pack save shows an error and a retry', (tester) async {
    await pumpShell(
      tester,
      _starterPack.copyWith(actionStatus: ActionStatus.inProgress),
      _starterPack.copyWith(actionStatus: ActionStatus.failure),
    );

    expect(toasts, <String>["Couldn't follow these creators. Try again."]);
    expect(find.text('try again'), findsOneWidget);
    expect(find.textContaining("couldn't follow these creators"), findsOneWidget);
  });

  testWidgets('interests retry redispatches the interests save event', (tester) async {
    final bloc = await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(actionStatus: ActionStatus.failure),
    );

    await tester.tap(find.text('try again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    verify(() => bloc.add(const OnboardingV2Event.interestsConfirmed())).called(1);
  });

  testWidgets('an interests retry ignores stale AI loading from a previous step', (tester) async {
    final bloc = await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(
        actionStatus: ActionStatus.failure,
        aiData: OnboardingAiData.initial().copyWith(status: AiGenerateStatus.loading),
      ),
    );

    await tester.tap(find.text('try again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    verify(() => bloc.add(const OnboardingV2Event.interestsConfirmed())).called(1);
  });

  testWidgets('starter pack retry redispatches the follow event', (tester) async {
    final bloc = await pumpShell(
      tester,
      _starterPack.copyWith(actionStatus: ActionStatus.inProgress),
      _starterPack.copyWith(actionStatus: ActionStatus.failure),
    );

    await tester.tap(find.text('try again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    verify(() => bloc.add(const OnboardingV2Event.starterPackConfirmed())).called(1);
  });

  testWidgets('save failure toast only repeats for a new failed attempt', (tester) async {
    final failure = _interests.copyWith(actionStatus: ActionStatus.failure);
    await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      failure,
      states: Stream<OnboardingV2State>.fromIterable(<OnboardingV2State>[
        failure,
        failure.copyWith(interestsData: failure.interestsData.copyWith(selected: const <String>['Abstract', 'Space'])),
        _interests.copyWith(actionStatus: ActionStatus.inProgress),
        failure,
      ]),
    );

    expect(toasts, <String>["Couldn't save your picks. Try again.", "Couldn't save your picks. Try again."]);
  });

  testWidgets('a skipped-interests completion failure retries completion, not the starter pack save', (tester) async {
    final bloc = await pumpShell(
      tester,
      _starterPack.copyWith(actionStatus: ActionStatus.inProgress, skipInterests: true),
      _starterPack.copyWith(
        actionStatus: ActionStatus.failure,
        skipInterests: true,
        completionFailed: true,
        starterPackData: _starterPack.starterPackData.copyWith(selectedEmails: <String>{}),
      ),
    );

    expect(toasts, <String>["Couldn't finish setup. Try again."]);
    expect(find.text('try again'), findsOneWidget);
    expect(find.textContaining("couldn't finish setup"), findsOneWidget);

    await tester.tap(find.text('try again'));
    await tester.pump();

    verify(() => bloc.add(const OnboardingV2Event.completionRetried())).called(1);
    verifyNever(() => bloc.add(const OnboardingV2Event.starterPackConfirmed()));
  });

  testWidgets('an auth completion failure offers its helper and retry without accepted terms', (tester) async {
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final state = OnboardingV2State.initial().copyWith(actionStatus: ActionStatus.failure, completionFailed: true);
      final bloc = await pumpShell(
        tester,
        OnboardingV2State.initial().copyWith(actionStatus: ActionStatus.inProgress),
        state,
      );

      expect(find.text('try again'), findsOneWidget);
      expect(find.textContaining("couldn't finish setup"), findsOneWidget);
      expect(find.textContaining('I agree to the'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Browse without an account'), findsNothing);

      await tester.tap(find.text('try again'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      verify(() => bloc.add(const OnboardingV2Event.completionRetried())).called(1);
    } finally {
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
    }
  });

  testWidgets('an auth completion retry shows loading on the primary action', (tester) async {
    await pumpShell(
      tester,
      OnboardingV2State.initial(),
      OnboardingV2State.initial().copyWith(actionStatus: ActionStatus.inProgress),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('a save refused for the session offers sign in again', (tester) async {
    await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(actionStatus: ActionStatus.failure, sessionInvalid: true),
    );

    expect(toasts, <String>['Your session has expired. Please sign in again.']);
    expect(find.text('sign in again'), findsOneWidget);
    expect(find.text('your session has expired. sign in again to continue'), findsOneWidget);
  });

  testWidgets('an invalid session keeps sign in enabled when interests are empty', (tester) async {
    var signOutCalls = 0;
    await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(
        actionStatus: ActionStatus.failure,
        sessionInvalid: true,
        interestsData: _interests.interestsData.copyWith(selected: const <String>[]),
        wallpaperData: const OnboardingWallpaperData(status: FirstWallpaperStatus.loading),
      ),
      signOutForRecovery: () async {
        signOutCalls++;
        return false;
      },
    );
    await tester.tap(find.text('sign in again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(signOutCalls, 1);
  });

  testWidgets('a starter pack save failure does not reuse stale wallpaper success', (tester) async {
    final _MockOnboardingBloc bloc = _MockOnboardingBloc();
    whenListen(
      bloc,
      Stream<OnboardingV2State>.value(
        _starterPack.copyWith(
          actionStatus: ActionStatus.failure,
          wallpaperData: const OnboardingWallpaperData(status: FirstWallpaperStatus.success),
        ),
      ),
      initialState: _starterPack.copyWith(
        actionStatus: ActionStatus.inProgress,
        wallpaperData: const OnboardingWallpaperData(status: FirstWallpaperStatus.success),
      ),
    );
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<OnboardingV2Bloc>(bloc);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));

    await tester.pumpWidget(const MaterialApp(home: OnboardingV2Shell()));
    await tester.pump(const Duration(seconds: 1));

    expect(toasts, <String>["Couldn't follow these creators. Try again."]);
    verifyNever(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued()));
  });

  testWidgets('a completion failure with stale wallpaper success does not continue onboarding', (tester) async {
    final bloc = _MockOnboardingBloc();
    final from = OnboardingV2State.initial().copyWith(
      step: OnboardingV2Step.firstWallpaper,
      actionStatus: ActionStatus.inProgress,
      wallpaperData: const OnboardingWallpaperData(status: FirstWallpaperStatus.success),
    );
    whenListen(
      bloc,
      Stream<OnboardingV2State>.value(from.copyWith(actionStatus: ActionStatus.failure, completionFailed: true)),
      initialState: from,
    );
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<OnboardingV2Bloc>(bloc);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));

    await tester.pumpWidget(const MaterialApp(home: OnboardingV2Shell()));
    await tester.pump(const Duration(seconds: 1));

    expect(toasts, <String>["Couldn't finish setup. Try again."]);
    verifyNever(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued()));
  });

  testWidgets('an invalid session can recover when wallpaper loading state is stale', (tester) async {
    var signOutCalls = 0;
    await pumpShell(
      tester,
      OnboardingV2State.initial().copyWith(
        step: OnboardingV2Step.firstWallpaper,
        actionStatus: ActionStatus.inProgress,
        wallpaperData: const OnboardingWallpaperData(status: FirstWallpaperStatus.loading),
      ),
      OnboardingV2State.initial().copyWith(
        step: OnboardingV2Step.firstWallpaper,
        actionStatus: ActionStatus.failure,
        completionFailed: true,
        sessionInvalid: true,
        wallpaperData: const OnboardingWallpaperData(status: FirstWallpaperStatus.loading),
      ),
      signOutForRecovery: () async {
        signOutCalls++;
        return false;
      },
    );

    expect(find.text('sign in again'), findsOneWidget);
    await tester.tap(find.text('sign in again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(signOutCalls, 1);
  });

  testWidgets('a failed sign out keeps local onboarding state and does not restart', (tester) async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
    await settings.set('onboarded_v2_new', true);
    await settings.set('onboarding_v2_interests', 'saved interests');
    await settings.set('onboarding_v2_followed_creators', 'saved creators');
    var signOutCalls = 0;
    var mountCalls = 0;
    final GoogleAuth auth = GoogleAuth(
      auth: _FakeAuth(user: _FakeUser(), signOutError: StateError('Firebase auth unavailable')),
      googleSignIn: _FakeGoogleSignIn(),
      messaging: _FakeMessaging(),
    );
    getIt.registerSingleton<FirestoreClient>(_FakeFirestore());

    await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(actionStatus: ActionStatus.failure, sessionInvalid: true),
      settings: settings,
      signOutForRecovery: () {
        signOutCalls++;
        return auth.signOutGoogle();
      },
      onMount: () => mountCalls++,
    );
    await tester.tap(find.text('sign in again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(signOutCalls, 1);
    expect(mountCalls, 1);
    expect(settings.get<bool>('onboarded_v2_new'), isTrue);
    expect(settings.get<String>('onboarding_v2_interests'), 'saved interests');
    expect(settings.get<String>('onboarding_v2_followed_creators'), 'saved creators');
    expect(find.text('sign in again'), findsOneWidget);
    expect(toasts.last, 'Could not log out. Please try again.');
  });

  testWidgets('a Firestore outage does not block shared sign out, local reset, or restart', (tester) async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(store);
    await settings.set('onboarded_v2_new', true);
    await settings.set('onboarding_v2_interests', 'saved interests');
    await settings.set('onboarding_v2_followed_creators', 'saved creators');
    var mountCalls = 0;
    final GoogleAuth auth = GoogleAuth(
      auth: _FakeAuth(user: _FakeUser()),
      googleSignIn: _FakeGoogleSignIn(),
      messaging: _FakeMessaging(),
    );
    getIt.registerSingleton<FirestoreClient>(_FakeFirestore());

    await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(actionStatus: ActionStatus.failure, sessionInvalid: true),
      settings: settings,
      signOutForRecovery: auth.signOutGoogle,
      onMount: () => mountCalls++,
    );
    await tester.tap(find.text('sign in again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(mountCalls, 2);
    expect(settings.get<bool>('onboarded_v2_new'), isFalse);
    expect(settings.get<String>('onboarding_v2_interests'), '');
    expect(settings.get<String>('onboarding_v2_followed_creators'), '');
  });

  testWidgets('a local reset failure releases the sign-out loading state for retry', (tester) async {
    var signOutCalls = 0;
    final settings = SettingsLocalDataSource(_FailingSetLocalStore());
    await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(actionStatus: ActionStatus.failure, sessionInvalid: true),
      settings: settings,
      signOutForRecovery: () async {
        signOutCalls++;
        return true;
      },
    );

    await tester.tap(find.text('sign in again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(signOutCalls, 1);
    expect(find.text('sign in again'), findsOneWidget);
    expect(toasts.last, 'Could not log out. Please try again.');
  });

  testWidgets('sign in again blocks repeated taps and back navigation while signing out', (tester) async {
    final Completer<bool> pendingSignOut = Completer<bool>();
    var signOutCalls = 0;
    final bloc = await pumpShell(
      tester,
      _interests.copyWith(actionStatus: ActionStatus.inProgress),
      _interests.copyWith(actionStatus: ActionStatus.failure, sessionInvalid: true),
      signOutForRecovery: () {
        signOutCalls++;
        return pendingSignOut.future;
      },
    );
    final buttonCenter = tester.getRect(find.text('sign in again')).center;

    await tester.tapAt(buttonCenter);
    await tester.pump();
    await tester.tapAt(buttonCenter);
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(signOutCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    verifyNever(() => bloc.add(const OnboardingV2Event.stepBack()));

    pendingSignOut.complete(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  });
}
