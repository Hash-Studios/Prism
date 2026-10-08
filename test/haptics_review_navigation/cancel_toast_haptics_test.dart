// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

import '../support/in_memory_local_store.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

class _CancelledGoogleSignInPlatform extends GoogleSignInPlatform {
  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async =>
      throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);

  @override
  bool authorizationRequiresUserInteraction() => true;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel hapticsChannel = MethodChannel('prism/haptics');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> haptics = <String>[];
  final List<String> toasts = <String>[];
  late GoogleSignInPlatform originalGoogleSignInPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    originalGoogleSignInPlatform = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = _CancelledGoogleSignInPlatform();
    PrismHaptics.enabled = true;
    haptics.clear();
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      hapticsChannel,
      (MethodCall call) async => haptics.add(call.arguments! as String),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
  });

  tearDown(() async {
    GoogleSignInPlatform.instance = originalGoogleSignInPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(hapticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    await getIt.reset();
  });

  testWidgets('cancelled Google sign-in keeps its toast without adding an error haptic', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _MockOnboardingBloc bloc = _MockOnboardingBloc();
    whenListen(bloc, const Stream<OnboardingV2State>.empty(), initialState: OnboardingV2State.initial());
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<OnboardingV2Bloc>(bloc);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));

    await tester.pumpWidget(const MaterialApp(home: OnboardingV2Shell()));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    haptics.clear();

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump();

    expect(toasts, <String>['Sign in cancelled.']);
    expect(haptics, <String>['tap']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
