import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

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
    await getIt.reset();
  });

  Future<void> pumpShell(WidgetTester tester, OnboardingV2State from, OnboardingV2State to) async {
    final _MockOnboardingBloc bloc = _MockOnboardingBloc();
    whenListen(bloc, Stream<OnboardingV2State>.value(to), initialState: from);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<OnboardingV2Bloc>(bloc);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));

    await tester.pumpWidget(const MaterialApp(home: OnboardingV2Shell()));
    await tester.pump(const Duration(seconds: 1));
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
}
