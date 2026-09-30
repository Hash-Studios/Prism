import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/audio/app_sound_manager.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f0_auth_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f1_interests_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f2_starter_pack_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f4_first_wallpaper_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage(name: 'OnboardingV2ShellRoute')
class OnboardingV2Shell extends StatefulWidget {
  const OnboardingV2Shell({super.key});

  @override
  State<OnboardingV2Shell> createState() => _OnboardingV2ShellState();
}

class _OnboardingV2ShellState extends State<OnboardingV2Shell> {
  late final OnboardingV2Bloc _bloc;
  late final TapGestureRecognizer _legalTap;
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool _imagesPrecached = false;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<OnboardingV2Bloc>();
    _bloc.add(const OnboardingV2Event.started());
    AppSoundManager.instance.playOnboardingSwoosh();
    // Once accepted, don't ask again on a later onboarding run (e.g. after logout).
    _termsAccepted = _settingsLocal.get<bool>(OnboardingV2Config.termsAcceptedKey, defaultValue: false);
    _legalTap = TapGestureRecognizer()
      ..onTap = () => launchUrl(Uri.parse(OnboardingV2Config.termsUrl), mode: LaunchMode.externalApplication);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      applyEdgeToEdgeOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      precacheImage(const AssetImage(OnboardingAssets.wallpaperPrimary), context);
    }
  }

  @override
  void dispose() {
    _legalTap.dispose();
    _bloc.close();
    super.dispose();
  }

  Future<void> _handleNavRequest(BuildContext context, OnboardingV2NavRequest request) async {
    switch (request) {
      case OnboardingV2NavRequest.openPaywall:
        if (!context.mounted) return;
        final paywallResult = await PaywallOrchestrator.instance.present(
          placement: OnboardingV2Config.paywallPlacement,
          source: OnboardingV2Config.paywallSource,
        );
        if (!context.mounted) return;
        _bloc.add(OnboardingV2Event.paywallResultReceived(didPurchase: paywallResult.indicatesPurchase));

      case OnboardingV2NavRequest.completeOnboarding:
        if (!context.mounted) return;
        context.router.replaceAll([const SplashWidgetRoute()]);
    }
  }

  Future<void> _handleGoogleSignIn() => _runSignIn(globalGoogleAuth.signInWithGoogle, _googleErrorMessage);

  Future<void> _handleAppleSignIn() => _runSignIn(globalAppleAuth.signInWithApple, (_) => _genericSignInError);

  static const String _genericSignInError = 'Something went wrong. Try again.';

  String _googleErrorMessage(Object error) {
    final String message = error.toString();
    final bool isPlayServicesError =
        defaultTargetPlatform == TargetPlatform.android &&
        (message.contains('providerConfigurationError') || message.contains('no provider dependencies'));
    return isPlayServicesError ? 'Google Play services on this device cannot sign in.' : _genericSignInError;
  }

  Future<void> _runSignIn(Future<SignInOutcome> Function() signIn, String Function(Object error) errorMessage) async {
    _bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: true));
    try {
      final result = await signIn();
      if (!mounted) return;
      if (result == SignInOutcome.cancelled) {
        app_state.prismUser.loggedIn = false;
        app_state.persistPrismUser();
        toasts.error('Sign in cancelled.');
        _bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
      } else {
        app_state.prismUser.loggedIn = true;
        app_state.persistPrismUser();
        _bloc.add(const OnboardingV2Event.authCompleted());
      }
    } catch (error) {
      if (mounted) toasts.error(errorMessage(error));
      _bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
    }
  }

  void _setTermsAccepted(bool accepted) {
    setState(() => _termsAccepted = accepted);
    _settingsLocal.set(OnboardingV2Config.termsAcceptedKey, accepted);
  }

  /// iOS-only guest path (Guideline 5.1.1(v)): browsing must not require an
  /// account. Marks onboarding done the same way a completed sign-in flow
  /// does, then goes straight to the dashboard signed out.
  Future<void> _handleBrowseWithoutAccount() async {
    await _settingsLocal.set(OnboardingV2Keys.onboardedNew, true);
    if (!mounted) return;
    context.router.replaceAll([const DashboardRoute()]);
  }

  Widget _pageFor(OnboardingV2Step step) => KeyedSubtree(
    key: ValueKey(step),
    child: switch (step) {
      OnboardingV2Step.auth => F0AuthPage(
        termsAccepted: _termsAccepted,
        onTermsChanged: _setTermsAccepted,
        legalTap: _legalTap,
        onGoogle: _handleGoogleSignIn,
        onApple: _handleAppleSignIn,
        onBrowse: _handleBrowseWithoutAccount,
      ),
      OnboardingV2Step.interests => const F1InterestsPage(),
      OnboardingV2Step.starterPack => const F2StarterPackPage(),
      OnboardingV2Step.aiGenerate => const F3AiGeneratePage(),
      OnboardingV2Step.firstWallpaper => const F4FirstWallpaperPage(),
    },
  );

  /// Steps 1 to 4 carry the progress bar. The fill runs to this many quarters.
  static int _progressFor(OnboardingV2Step step) => switch (step) {
    OnboardingV2Step.auth || OnboardingV2Step.interests => 1,
    OnboardingV2Step.starterPack => 2,
    OnboardingV2Step.aiGenerate => 3,
    OnboardingV2Step.firstWallpaper => 4,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: [
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) => curr.navRequest != null && prev.navRequest != curr.navRequest,
            listener: (context, state) => _handleNavRequest(context, state.navRequest!),
          ),
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) =>
                curr.step == OnboardingV2Step.firstWallpaper &&
                prev.wallpaperData.status != curr.wallpaperData.status &&
                curr.wallpaperData.status == FirstWallpaperStatus.success,
            listener: (context, state) {
              if (state.navRequest != null) return;
              toasts.success(defaultTargetPlatform == TargetPlatform.android ? 'Wallpaper set!' : 'Saved to Photos!');
              showGlintToast(context, mood: GlintMood.celebrate);
              _bloc.add(const OnboardingV2Event.firstWallpaperStepContinued());
            },
          ),
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) =>
                curr.step == OnboardingV2Step.firstWallpaper &&
                prev.wallpaperData.status != curr.wallpaperData.status &&
                curr.wallpaperData.status == FirstWallpaperStatus.failure,
            listener: (context, state) => toasts.error(
              defaultTargetPlatform == TargetPlatform.android
                  ? 'Could not set the wallpaper. Try again.'
                  : 'Could not save the wallpaper. Try again.',
            ),
          ),
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) =>
                curr.step == OnboardingV2Step.aiGenerate &&
                prev.aiData.status != AiGenerateStatus.success &&
                curr.aiData.status == AiGenerateStatus.success,
            listener: (context, state) => _bloc.add(const OnboardingV2Event.aiGenerationStepContinued()),
          ),
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) =>
                prev.actionStatus != curr.actionStatus &&
                curr.actionStatus == ActionStatus.failure &&
                curr.step != OnboardingV2Step.firstWallpaper,
            listener: (context, state) => toasts.error('Something went wrong. Try again.'),
          ),
        ],
        child: BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
          buildWhen: (prev, curr) => prev.step != curr.step,
          builder: (context, state) {
            final OnboardingV2Step step = state.step;
            final bool welcome = step == OnboardingV2Step.auth;
            final bool darkTheme = Theme.of(context).brightness == Brightness.dark;
            final Brightness icons = welcome || darkTheme ? Brightness.light : Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: edgeToEdgeOverlayStyle(statusBarIconBrightness: icons, systemNavigationBarIconBrightness: icons),
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  _bloc.add(const OnboardingV2Event.stepBack());
                },
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(child: OnboardingStepBackground(visible: welcome)),
                      _StepSwitcher(step: step, child: _pageFor(step)),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              duration: context.motion(PrismDurations.base),
                              opacity: welcome ? 0 : 1,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, 0),
                                child: OnboardingProgressBar(step: _progressFor(step)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cross-fades between steps. The step that arrives also rises 8 points.
class _StepSwitcher extends StatelessWidget {
  const _StepSwitcher({required this.step, required this.child});

  final OnboardingV2Step step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.base),
      switchInCurve: PrismCurves.enter,
      switchOutCurve: PrismCurves.exit,
      transitionBuilder: (child, animation) {
        final bool arriving = child.key == ValueKey(step);
        return FadeTransition(
          opacity: animation,
          child: arriving
              ? AnimatedBuilder(
                  animation: animation,
                  child: child,
                  builder: (context, child) =>
                      Transform.translate(offset: Offset(0, 8 * (1 - animation.value)), child: child),
                )
              : child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) =>
          Stack(fit: StackFit.expand, children: [...previousChildren, if (currentChild != null) currentChild]),
      child: child,
    );
  }
}
