// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

const MethodChannel _hapticsChannel = MethodChannel('prism/haptics');
const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockOnboardingBloc bloc;
  late StreamController<OnboardingV2State> states;
  late FakeAppAnalytics analytics;
  late SettingsLocalDataSource settings;
  late _FakeUrlLauncher urlLauncher;
  late UrlLauncherPlatform originalUrlLauncher;
  final List<String> toasts = <String>[];

  setUpAll(() => registerFallbackValue(const OnboardingV2Event.started()));

  setUp(() {
    toasts.clear();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    PrismHaptics.enabled = false;
    IosWallpaperGuideSession.shown = false;
    originalUrlLauncher = UrlLauncherPlatform.instance;
    urlLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _hapticsChannel,
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    // The notification prompt returns early when it was asked before.
    settings.set('notificationPermissionPromptedV2', true);
    bloc = _MockOnboardingBloc();
    states = StreamController<OnboardingV2State>.broadcast();
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerSingleton<OnboardingV2Bloc>(bloc);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
  });

  tearDown(() async {
    UrlLauncherPlatform.instance = originalUrlLauncher;
    AnalyticsRuntime.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_hapticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, null);
    await states.close();
    await getIt.reset();
  });

  Future<void> pumpShell(WidgetTester tester, OnboardingV2State initial) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(bloc, states.stream, initialState: initial);
    await tester.pumpWidget(const MaterialApp(home: OnboardingV2Shell()));
    await tester.pump(const Duration(seconds: 1));
  }

  OnboardingV2State wallpaperStep({
    FirstWallpaperStatus status = FirstWallpaperStatus.loading,
    String? errorCode,
    WallpaperTarget? target,
  }) => OnboardingV2State.initial().copyWith(
    step: OnboardingV2Step.firstWallpaper,
    wallpaperData: OnboardingWallpaperData(status: status, errorCode: errorCode, target: target),
  );

  Future<void> emit(WidgetTester tester, OnboardingV2State state) async {
    states.add(state);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Lets the toast timer run out so no timer outlives the test.
  Future<void> settleToasts(WidgetTester tester) => tester.pump(const Duration(seconds: 2));

  group('sign-in step', () {
    testWidgets('names the Terms and the Privacy policy and opens both links', (tester) async {
      await pumpShell(tester, OnboardingV2State.initial());

      final row = tester.widget<RichText>(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().startsWith('By continuing')),
      );
      expect(row.text.toPlainText(), 'By continuing you agree to the Terms and Privacy policy');
      final spans = (row.text as TextSpan).children!.whereType<TextSpan>().toList();
      (spans.singleWhere((s) => s.text == 'Terms').recognizer! as TapGestureRecognizer).onTap!();
      (spans.singleWhere((s) => s.text == 'Privacy policy').recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();

      expect(urlLauncher.launched, <String>[OnboardingV2Config.termsUrl, OnboardingV2Config.privacyUrl]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('ticking the checkbox records terms_accepted once', (tester) async {
      await pumpShell(tester, OnboardingV2State.initial());

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(analytics.events.map((e) => e.eventName), <String>['terms_accepted']);
      expect(settings.get<bool>(OnboardingV2Config.termsAcceptedKey, defaultValue: false), isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(analytics.events.map((e) => e.eventName), <String>['terms_accepted']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the blocked button tells the user to accept the Terms and Privacy policy', (tester) async {
      await pumpShell(tester, OnboardingV2State.initial());

      await tester.tap(find.text('Continue with Google'), warnIfMissed: false);
      await tester.pump();

      expect(toasts, <String>['Please agree to the Terms and Privacy policy first.']);
      await settleToasts(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('browsing without an account records the tap and starts the guest path', (tester) async {
      await pumpShell(tester, OnboardingV2State.initial());
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.text('Browse without an account'));
      await tester.pump();

      expect(analytics.events.map((e) => e.eventName), contains('browse_as_guest_tapped'));
      verify(() => bloc.add(const OnboardingV2Event.guestBrowseStarted())).called(1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android has no guest button', (tester) async {
      await pumpShell(tester, OnboardingV2State.initial());

      expect(find.text('Browse without an account'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('AI step copy', () {
    testWidgets('no longer tells the user to tap a button that does not exist', (tester) async {
      final initial = OnboardingV2State.initial().copyWith(step: OnboardingV2Step.aiGenerate);
      await pumpShell(tester, initial);

      await emit(
        tester,
        initial.copyWith(
          aiData: initial.aiData.copyWith(status: AiGenerateStatus.success, imageUrl: '', thumbnailUrl: ''),
        ),
      );

      expect(find.text('looking good! opening your wallpaper'), findsOneWidget);
      expect(find.textContaining('use this wallpaper'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('first wallpaper failure', () {
    testWidgets('Android shows a message with Try again and the button works again', (tester) async {
      await pumpShell(tester, wallpaperStep());

      await emit(tester, wallpaperStep(status: FirstWallpaperStatus.failure, errorCode: 'image-too-large'));

      expect(find.text("Couldn't set your wallpaper. Try again or skip."), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      verify(() => bloc.add(const OnboardingV2Event.firstWallpaperActionRequested())).called(1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS says it could not save and offers Try again', (tester) async {
      await pumpShell(tester, wallpaperStep());

      await emit(tester, wallpaperStep(status: FirstWallpaperStatus.failure));

      expect(find.text("Couldn't save your wallpaper. Try again or skip."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS with Photos access off points to Settings', (tester) async {
      await pumpShell(tester, wallpaperStep());

      await emit(tester, wallpaperStep(status: FirstWallpaperStatus.failure, errorCode: photosPermissionDeniedCode));

      expect(find.text('Allow Prism to add photos in Settings to save wallpapers.'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a failure on another step shows nothing', (tester) async {
      await pumpShell(tester, OnboardingV2State.initial().copyWith(step: OnboardingV2Step.aiGenerate));

      await emit(
        tester,
        OnboardingV2State.initial().copyWith(
          step: OnboardingV2Step.aiGenerate,
          wallpaperData: const OnboardingWallpaperData(status: FirstWallpaperStatus.failure),
        ),
      );

      expect(find.byType(SnackBar), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('first wallpaper success', () {
    testWidgets('Android names the home and lock screens and moves on', (tester) async {
      await pumpShell(tester, wallpaperStep());

      await emit(tester, wallpaperStep(status: FirstWallpaperStatus.success, target: WallpaperTarget.both));
      await tester.pump(const Duration(milliseconds: 50));

      expect(toasts, <String>['Wallpaper set on your home and lock screens.']);
      verify(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued())).called(1);
      await settleToasts(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Android names the single screen when the device cannot set both', (tester) async {
      await pumpShell(tester, wallpaperStep());

      await emit(tester, wallpaperStep(status: FirstWallpaperStatus.success, target: WallpaperTarget.home));

      expect(toasts, <String>['Wallpaper set on your home screen.']);
      await settleToasts(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS shows the set-wallpaper guide before it moves on', (tester) async {
      await pumpShell(tester, wallpaperStep());

      await emit(tester, wallpaperStep(status: FirstWallpaperStatus.success));

      expect(toasts, <String>['Saved to Photos!']);
      expect(find.byType(IosWallpaperGuideSheet), findsOneWidget);
      verifyNever(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued()));

      Navigator.of(tester.element(find.byType(IosWallpaperGuideSheet))).pop();
      await tester.pumpAndSettle();

      verify(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued())).called(1);
      await settleToasts(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS moves on at once when the guide already showed in this session', (tester) async {
      IosWallpaperGuideSession.shown = true;
      await pumpShell(tester, wallpaperStep());

      await emit(tester, wallpaperStep(status: FirstWallpaperStatus.success));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(IosWallpaperGuideSheet), findsNothing);
      verify(() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued())).called(1);
      await settleToasts(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
