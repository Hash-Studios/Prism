import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/audio/app_sound_manager.dart';
import 'package:Prism/core/auth/guest_browsing_policy.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/ios_wallpaper_guide.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/ai_target_size.dart';
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/utils/wallpaper_brightness.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f0_auth_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f1_interests_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f2_starter_pack_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_ai_generate_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f4_first_wallpaper_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_progress_indicator.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_recovery.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_scrollable_canvas.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_staggered_fade.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/welcome_background.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/features/taste_quiz/taste_quiz.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

String _saveErrorHelper(OnboardingV2State state, AppLocalizations l10n) {
  if (state.sessionInvalid) return l10n.onboardingRecoverySessionExpiredHelper;
  if (state.completionFailed) return l10n.onboardingRecoverySetupFailedHelper;
  return state.step == OnboardingV2Step.interests
      ? l10n.onboardingRecoverySaveInterestsFailedHelper
      : l10n.onboardingRecoveryFollowFailedHelper;
}

String _saveErrorToast(OnboardingV2State state, AppLocalizations l10n) {
  if (state.sessionInvalid) return l10n.onboardingRecoverySessionExpired;
  if (state.completionFailed) return l10n.onboardingRecoverySetupFailed;
  return state.step == OnboardingV2Step.interests
      ? l10n.onboardingRecoverySaveInterestsFailed
      : l10n.onboardingRecoveryFollowFailed;
}

@RoutePage(name: 'OnboardingV2ShellRoute')
class OnboardingV2Shell extends StatefulWidget {
  const OnboardingV2Shell({super.key, @visibleForTesting this.signOutForRecovery});

  @visibleForTesting
  final Future<bool> Function()? signOutForRecovery;

  @override
  State<OnboardingV2Shell> createState() => _OnboardingV2ShellState();
}

class _OnboardingV2ShellState extends State<OnboardingV2Shell> {
  late final OnboardingV2Bloc _bloc;
  late final TapGestureRecognizer _legalTap;
  late final TapGestureRecognizer _privacyTap;
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool _imagesPrecached = false;
  bool _termsAccepted = false;
  bool _signingOut = false;

  /// The welcome art is dark under the pitch, so its icons are light.
  static final _welcomeUiStyle = edgeToEdgeOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// Steps 1 to 4 sit on the blurred, light art, so the status bar icons are dark.
  static final _systemUiStyle = edgeToEdgeOverlayStyle(
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// The quiz sits on the theme surface, so its icons follow the theme.
  static SystemUiOverlayStyle _themedUiStyle(BuildContext context) {
    final Brightness icons = Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    return edgeToEdgeOverlayStyle(statusBarIconBrightness: icons, systemNavigationBarIconBrightness: icons);
  }

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
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => launchUrl(Uri.parse(OnboardingV2Config.privacyUrl), mode: LaunchMode.externalApplication);
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
    _privacyTap.dispose();
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

      case OnboardingV2NavRequest.openDashboardAsGuest:
        if (!context.mounted || !guestBrowsingAllowed) return;
        context.router.replaceAll([const DashboardRoute()]);

      case OnboardingV2NavRequest.exitApp:
        SystemNavigator.pop();
    }
  }

  Future<void> _onFirstWallpaperSaved(BuildContext context, OnboardingWallpaperData wallpaperData) async {
    toasts.success(_firstWallpaperSuccessMessage(wallpaperData.target, context.l10n));
    // iOS cannot set the wallpaper from the app, so show how to finish in Photos. The guide skips itself elsewhere.
    await showIosSetWallpaperGuide(context);
    if (!context.mounted) return;
    await _continueAfterFirstWallpaper(context);
  }

  static String _firstWallpaperSuccessMessage(WallpaperTarget? target, AppLocalizations l10n) {
    if (defaultTargetPlatform != TargetPlatform.android) return l10n.onboardingFirstWallpaperSavedPhotos;
    return switch (target) {
      WallpaperTarget.both => l10n.onboardingFirstWallpaperSetHomeLock,
      WallpaperTarget.home => l10n.onboardingFirstWallpaperSetHome,
      WallpaperTarget.lock => l10n.onboardingFirstWallpaperSetLock,
      null => l10n.onboardingFirstWallpaperSet,
    };
  }

  void _onFirstWallpaperFailed(BuildContext context, OnboardingWallpaperData wallpaperData) {
    if (defaultTargetPlatform == TargetPlatform.iOS && isPhotosPermissionDenied(wallpaperData.errorCode)) {
      showPhotosPermissionDenied(context);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    PrismHaptics.error();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            defaultTargetPlatform == TargetPlatform.android
                ? context.l10n.onboardingFirstWallpaperSetFailed
                : context.l10n.onboardingFirstWallpaperSaveFailed,
          ),
          action: SnackBarAction(
            label: context.l10n.onboardingRecoveryRetry,
            onPressed: () => _bloc.add(const OnboardingV2Event.firstWallpaperActionRequested()),
          ),
        ),
      );
  }

  Future<void> _continueAfterFirstWallpaper(BuildContext context) async {
    try {
      await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
        context,
        sourceTag: 'onboarding_v2.first_wallpaper',
      );
    } catch (error, stackTrace) {
      logger.w('Onboarding notification prompt failed.', tag: 'OnboardingV2', error: error, stackTrace: stackTrace);
    }
    if (!mounted) return;
    _bloc.add(const OnboardingV2Event.firstWallpaperStepContinued());
  }

  Future<void> _handleGoogleSignIn() =>
      _runSignIn(globalGoogleAuth.signInWithGoogle, (Object error) => googleSignInErrorMessage(error, context.l10n));

  Future<void> _handleAppleSignIn() =>
      _runSignIn(globalAppleAuth.signInWithApple, (_) => genericSignInErrorMessage(context.l10n));

  Future<void> _runSignIn(Future<SignInOutcome> Function() signIn, String Function(Object error) errorMessage) async {
    _bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: true));
    try {
      final result = await signIn();
      if (!mounted) return;
      if (result == SignInOutcome.cancelled) {
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

  /// The account behind this session is gone or locked out, so no save can succeed.
  /// Sign out the same way Settings does, then restart into a fresh onboarding.
  Future<void> _signInAgain() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    var signedOut = false;
    try {
      signedOut = await (widget.signOutForRecovery ?? globalGoogleAuth.signOutGoogle)();
    } catch (error, stackTrace) {
      logger.w('Sign out from onboarding failed.', error: error, stackTrace: stackTrace);
    }
    if (!signedOut) {
      if (mounted) {
        setState(() => _signingOut = false);
        toasts.error(context.l10n.onboardingCouldNotLogOut);
      }
      return;
    }
    try {
      await resetOnboardingLocalState(_settingsLocal);
      if (mounted) main.RestartWidget.restartApp(context);
    } catch (error, stackTrace) {
      logger.w('Could not reset onboarding state after sign out.', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _signingOut = false);
        toasts.error(context.l10n.onboardingCouldNotLogOut);
      }
    }
  }

  void _setTermsAccepted(bool accepted) {
    if (accepted && !_termsAccepted) unawaited(analytics.track(const TermsAcceptedEvent()));
    setState(() => _termsAccepted = accepted);
    _settingsLocal.set(OnboardingV2Config.termsAcceptedKey, accepted);
  }

  void _handleBrowseWithoutAccount() {
    if (!guestBrowsingAllowed) return;
    unawaited(analytics.track(const BrowseAsGuestTappedEvent()));
    _bloc.add(const OnboardingV2Event.guestBrowseStarted());
  }

  void _handleCtaTap(OnboardingV2Step step) {
    final state = _bloc.state;
    if (step != state.step) return;
    if (_signingOut || state.actionStatus == ActionStatus.inProgress) return;
    if (onboardingSaveFailed(state) && state.sessionInvalid) {
      _signInAgain();
      return;
    }
    if (onboardingStarterPackShort(state)) {
      _bloc.add(const OnboardingV2Event.starterPackReloadRequested());
      return;
    }
    if (onboardingSaveFailed(state) && state.completionFailed) {
      _bloc.add(const OnboardingV2Event.completionRetried());
      return;
    }
    if ((step == OnboardingV2Step.aiGenerate && state.aiData.status == AiGenerateStatus.loading) ||
        (step == OnboardingV2Step.firstWallpaper && state.wallpaperData.status == FirstWallpaperStatus.loading)) {
      return;
    }
    switch (step) {
      case OnboardingV2Step.auth:
      case OnboardingV2Step.tasteQuiz:
        // The welcome page and the quiz have their own buttons.
        return;
      case OnboardingV2Step.interests:
        _bloc.add(const OnboardingV2Event.interestsConfirmed());
      case OnboardingV2Step.starterPack:
        _bloc.add(const OnboardingV2Event.starterPackConfirmed());
      case OnboardingV2Step.aiGenerate:
        // Success auto-advances via the shell listener; CTA always triggers or re-triggers generation.
        _bloc.add(OnboardingV2Event.aiGenerationRequested(targetSize: _targetSizeForDevice()));
      case OnboardingV2Step.firstWallpaper:
        final wallpaper = _bloc.state.wallpaperData.wallpaper;
        if (wallpaper == null) {
          _bloc.add(const OnboardingV2Event.firstWallpaperStepContinued());
        } else {
          _bloc.add(const OnboardingV2Event.firstWallpaperActionRequested());
        }
    }
  }

  String _targetSizeForDevice() {
    if (!mounted) return '1080x1920';
    final media = MediaQuery.of(context);
    return aiTargetSize(size: media.size, devicePixelRatio: media.devicePixelRatio);
  }

  /// The welcome page keeps the redesign. It draws its own art, copy and buttons, so it takes no part in the shared
  /// overlay of steps 1 to 4.
  Widget _welcomePage() => KeyedSubtree(
    key: _welcomeKey,
    child: _RecoveryHost(
      bloc: _bloc,
      signingOut: _signingOut,
      signInAgain: _signInAgain,
      child: F0AuthPage(
        termsAccepted: _termsAccepted,
        onTermsChanged: _setTermsAccepted,
        legalTap: _legalTap,
        privacyTap: _privacyTap,
        onGoogle: _handleGoogleSignIn,
        onApple: _handleAppleSignIn,
        onBrowse: _handleBrowseWithoutAccount,
      ),
    ),
  );

  /// The quiz shows the walls edge to edge, so like the welcome page it takes the whole canvas.
  Widget _tasteQuizPage(OnboardingV2State state) => KeyedSubtree(
    key: _tasteQuizKey,
    child: TasteQuizView(
      plan: state.tasteQuizPlan!,
      source: TasteQuizSource.onboarding,
      onFinished: (completed) => _bloc.add(OnboardingV2Event.tasteQuizFinished(completed: completed)),
    ),
  );

  static const Key _welcomeKey = ValueKey<String>('welcome');
  static const Key _tasteQuizKey = ValueKey<String>('taste_quiz');
  static const Key _stepsKey = ValueKey<String>('steps');

  Widget _pageFor(OnboardingV2Step step) => KeyedSubtree(
    key: ValueKey(step),
    child: switch (step) {
      // Never built: the welcome page and the quiz replace the whole canvas.
      OnboardingV2Step.auth || OnboardingV2Step.tasteQuiz => const SizedBox.shrink(),
      OnboardingV2Step.interests => const F1InterestsPage(),
      OnboardingV2Step.starterPack => const F2StarterPackPage(),
      OnboardingV2Step.aiGenerate => const F3AiGeneratePage(),
      OnboardingV2Step.firstWallpaper => const F4FirstWallpaperPage(),
    },
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: MultiBlocListener(
        listeners: <BlocListener<OnboardingV2Bloc, OnboardingV2State>>[
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) => !onboardingSaveFailed(prev) && onboardingSaveFailed(curr),
            listener: (context, state) => toasts.error(_saveErrorToast(state, context.l10n)),
          ),
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) =>
                curr.step == OnboardingV2Step.firstWallpaper &&
                prev.wallpaperData.status != FirstWallpaperStatus.failure &&
                curr.wallpaperData.status == FirstWallpaperStatus.failure,
            listener: (context, state) => _onFirstWallpaperFailed(context, state.wallpaperData),
          ),
        ],
        child: BlocConsumer<OnboardingV2Bloc, OnboardingV2State>(
          listenWhen: (prev, curr) {
            final navChanged = curr.navRequest != null && prev.navRequest != curr.navRequest;
            final wallpaperSucceeded =
                curr.step == OnboardingV2Step.firstWallpaper &&
                prev.wallpaperData.status != curr.wallpaperData.status &&
                curr.wallpaperData.status == FirstWallpaperStatus.success;
            final aiGenerationSucceeded =
                curr.step == OnboardingV2Step.aiGenerate &&
                prev.aiData.status != AiGenerateStatus.success &&
                curr.aiData.status == AiGenerateStatus.success;
            return navChanged || wallpaperSucceeded || aiGenerationSucceeded;
          },
          listener: (context, state) {
            if (state.navRequest != null) _handleNavRequest(context, state.navRequest!);
            if (state.navRequest == null && state.wallpaperData.status == FirstWallpaperStatus.success) {
              _onFirstWallpaperSaved(context, state.wallpaperData);
            }
            if (state.step == OnboardingV2Step.aiGenerate && state.aiData.status == AiGenerateStatus.success) {
              _bloc.add(const OnboardingV2Event.aiGenerationStepContinued());
            }
          },
          buildWhen: (prev, curr) =>
              prev.step != curr.step ||
              prev.isAuthLoading != curr.isAuthLoading ||
              prev.actionStatus != curr.actionStatus ||
              prev.sessionInvalid != curr.sessionInvalid ||
              prev.completionFailed != curr.completionFailed ||
              prev.loadStatus != curr.loadStatus ||
              prev.interestsData.available.length != curr.interestsData.available.length ||
              prev.interestsData.selected.length != curr.interestsData.selected.length ||
              prev.starterPackData.creators.length != curr.starterPackData.creators.length ||
              prev.starterPackData.selectedEmails.length != curr.starterPackData.selectedEmails.length ||
              prev.wallpaperData.status != curr.wallpaperData.status ||
              prev.wallpaperData.wallpaper?.thumbnailUrl != curr.wallpaperData.wallpaper?.thumbnailUrl ||
              prev.aiData != curr.aiData,
          builder: (context, state) {
            final bool welcome = state.step == OnboardingV2Step.auth;
            final bool tasteQuiz = state.step == OnboardingV2Step.tasteQuiz && state.tasteQuizPlan != null;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: welcome
                  ? _welcomeUiStyle
                  : tasteQuiz
                  ? _themedUiStyle(context)
                  : _systemUiStyle,
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (_signingOut) return;
                  _bloc.add(const OnboardingV2Event.stepBack());
                },
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: OnboardingLayout.maxTextScale,
                  // A Scaffold gives the snackbars a place to show.
                  child: Scaffold(
                    backgroundColor: OnboardingColors.fallbackFill,
                    resizeToAvoidBottomInset: false,
                    body: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layer 0: animated background (blur + image cross-fade), isolated in a
                        // RepaintBoundary from page content and overlay layers. It runs from the first frame, so
                        // it has settled by the time the welcome art fades out.
                        RepaintBoundary(
                          child: OnboardingStepBackground(
                            step: state.step,
                            wallpaperUrl: state.wallpaperData.wallpaper?.thumbnailUrl,
                          ),
                        ),

                        // The redesign's welcome art sits over layer 0 and fades out after the welcome step.
                        RepaintBoundary(child: WelcomeBackground(visible: welcome)),

                        _StepSwitcher(
                          current: welcome
                              ? _welcomeKey
                              : tasteQuiz
                              ? _tasteQuizKey
                              : _stepsKey,
                          child: welcome
                              ? _welcomePage()
                              : tasteQuiz
                              ? _tasteQuizPage(state)
                              : KeyedSubtree(
                                  key: _stepsKey,
                                  // Layers 1 and 2 share one scrollable canvas, so a short screen or large text
                                  // scrolls the page and its overlay together instead of overlapping them.
                                  child: OnboardingScrollableCanvas(
                                    children: [
                                      // Layer 1: unique page content, fades between steps.
                                      AnimatedSwitcher(
                                        duration: context.motion(const Duration(milliseconds: 300)),
                                        switchInCurve: Curves.easeOut,
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder: (child, animation) =>
                                            FadeTransition(opacity: animation, child: child),
                                        layoutBuilder: (currentChild, previousChildren) => Stack(
                                          fit: StackFit.expand,
                                          children: [...previousChildren, if (currentChild != null) currentChild],
                                        ),
                                        child: _pageFor(state.step),
                                      ),

                                      // Layer 2: shared animated overlay (headline, progress, button, helper),
                                      // isolated in a RepaintBoundary from the background and page layers.
                                      RepaintBoundary(
                                        child: _SharedOverlay(
                                          state: state,
                                          onCtaTap: () => _handleCtaTap(state.step),
                                          signingOut: _signingOut,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
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

/// Tells the welcome page what to do while a save error needs the user's attention.
class _RecoveryHost extends StatelessWidget {
  const _RecoveryHost({required this.bloc, required this.signingOut, required this.signInAgain, required this.child});

  final OnboardingV2Bloc bloc;
  final bool signingOut;
  final VoidCallback signInAgain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) =>
          prev.step != curr.step ||
          prev.actionStatus != curr.actionStatus ||
          prev.sessionInvalid != curr.sessionInvalid ||
          prev.completionFailed != curr.completionFailed ||
          prev.loadStatus != curr.loadStatus ||
          prev.starterPackData.creators.isEmpty != curr.starterPackData.creators.isEmpty,
      builder: (context, state) => OnboardingRecoveryScope(
        recovery: onboardingRecoveryFor(
          state,
          l10n: context.l10n,
          add: bloc.add,
          signInAgain: signInAgain,
          signingOut: signingOut,
        ),
        child: child,
      ),
    );
  }
}

/// Cross-fades between the welcome page, the quiz and steps 1 to 4. The page that arrives also rises 8 points.
class _StepSwitcher extends StatelessWidget {
  const _StepSwitcher({required this.current, required this.child});

  /// The key of the page on screen now.
  final Key current;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.base),
      switchInCurve: PrismCurves.enter,
      switchOutCurve: PrismCurves.exit,
      transitionBuilder: (child, animation) {
        final bool arriving = child.key == current;
        // One wrapper shape for both ways. A page that starts to leave keeps its state, so the quiz does not restart.
        return FadeTransition(
          opacity: animation,
          child: AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, arriving ? 8 * (1 - animation.value) : 0), child: child),
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) =>
          Stack(fit: StackFit.expand, children: [...previousChildren, if (currentChild != null) currentChild]),
      child: child,
    );
  }
}

/// Shared elements (headline, progress, button, helper text) that persist across steps 1 to 4.
class _SharedOverlay extends StatefulWidget {
  const _SharedOverlay({required this.state, required this.onCtaTap, required this.signingOut});

  final OnboardingV2State state;
  final VoidCallback onCtaTap;
  final bool signingOut;

  @override
  State<_SharedOverlay> createState() => _SharedOverlayState();
}

class _SharedOverlayState extends State<_SharedOverlay> {
  // Defaults to white so F4 is always legible before palette resolves.
  Color _wallpaperHeadlineColor = OnboardingColors.textOnDark;
  // Defaults to light icons (for dark wallpaper) before palette resolves.
  Brightness _statusBarIconBrightness = Brightness.light;

  @override
  void didUpdateWidget(_SharedOverlay old) {
    super.didUpdateWidget(old);
    final oldUrl = old.state.wallpaperData.wallpaper?.thumbnailUrl;
    final newUrl = widget.state.wallpaperData.wallpaper?.thumbnailUrl;
    if (newUrl != null && newUrl.isNotEmpty && newUrl != oldUrl) {
      _computeWallpaperHeadlineColor(newUrl);
    }
  }

  Future<void> _computeWallpaperHeadlineColor(String thumbnailUrl) async {
    final brightness = await wallpaperBrightness(thumbnailUrl);
    if (brightness == null || !mounted) return;
    setState(() {
      _wallpaperHeadlineColor = brightness == Brightness.light
          ? OnboardingColors.textPrimary
          : OnboardingColors.textOnDark;
      _statusBarIconBrightness = brightness == Brightness.light ? Brightness.dark : Brightness.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.state.step;
    final wallpaper = widget.state.wallpaperData.wallpaper;
    final aiStyle = wallpaper?.aiStyle;
    final wallpaperCategory = aiStyle == null ? wallpaper?.sourceCategory : aiStyleLabel(context.l10n, aiStyle);
    final overlayStyle = step == OnboardingV2Step.firstWallpaper
        ? edgeToEdgeOverlayStyle(
            statusBarIconBrightness: _statusBarIconBrightness,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : null;
    final content = OnboardingFrame(
      builder: (context, sx, sy) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _Progress(step: step, sx: sx, sy: sy, wallpaperColor: _wallpaperHeadlineColor),
            _Headline(step: step, sx: sx, sy: sy, wallpaperColor: _wallpaperHeadlineColor),
            if (step == OnboardingV2Step.firstWallpaper) _ProBadge(sy: sy, color: _wallpaperHeadlineColor),
            _CtaButton(
              step: step,
              sx: sx,
              sy: sy,
              state: widget.state,
              onCtaTap: widget.onCtaTap,
              signingOut: widget.signingOut,
            ),
            _BottomText(
              step: step,
              sy: sy,
              wallpaperCategory: wallpaperCategory,
              aiGenerateStatus: widget.state.aiData.status,
              errorText: onboardingSaveFailed(widget.state)
                  ? _saveErrorHelper(widget.state, context.l10n)
                  : onboardingStarterPackShort(widget.state)
                  ? context.l10n.onboardingRecoveryCreatorsFailed
                  : null,
              interestsRequired: widget.state.interestsData.requiredCount,
              creatorCount: widget.state.starterPackData.creators.length,
            ),
          ],
        );
      },
    );
    return overlayStyle != null ? AnnotatedRegion<SystemUiOverlayStyle>(value: overlayStyle, child: content) : content;
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.sx, required this.sy, required this.wallpaperColor});

  final OnboardingV2Step step;
  final double sx;
  final double sy;
  final Color wallpaperColor;

  @override
  Widget build(BuildContext context) {
    final progressStep = switch (step) {
      OnboardingV2Step.interests => 1,
      OnboardingV2Step.starterPack => 2,
      OnboardingV2Step.aiGenerate => 3,
      _ => 4,
    };

    final color = step == OnboardingV2Step.firstWallpaper ? wallpaperColor : OnboardingColors.progressActive;

    return Positioned(
      top: OnboardingLayout.progressY * sy,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.scale(
          scaleX: sx,
          scaleY: sy,
          alignment: Alignment.topCenter,
          child: OnboardingProgressIndicator(step: progressStep, totalSteps: 4, color: color),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.step, required this.sx, required this.sy, required this.wallpaperColor});

  final OnboardingV2Step step;
  final double sx;
  final double sy;

  /// Color used for the headline on the firstWallpaper step, derived from the wallpaper palette.
  final Color wallpaperColor;

  static double _headlineX(OnboardingV2Step step) => switch (step) {
    OnboardingV2Step.auth || OnboardingV2Step.tasteQuiz => 0,
    OnboardingV2Step.interests => OnboardingLayout.interestsTitleX,
    OnboardingV2Step.starterPack => OnboardingLayout.starterPackTitleX,
    OnboardingV2Step.aiGenerate => OnboardingLayout.aiTitleX,
    OnboardingV2Step.firstWallpaper => OnboardingLayout.aiTitleX,
  };

  static String _headlineText(OnboardingV2Step step, AppLocalizations l10n) => switch (step) {
    OnboardingV2Step.auth || OnboardingV2Step.tasteQuiz => '',
    OnboardingV2Step.interests => l10n.onboardingHeadlineInterests,
    OnboardingV2Step.starterPack => l10n.onboardingHeadlineCreators,
    OnboardingV2Step.aiGenerate => l10n.onboardingHeadlineGenerate,
    OnboardingV2Step.firstWallpaper => l10n.onboardingHeadlineCustomize,
  };

  @override
  Widget build(BuildContext context) {
    final text = _headlineText(step, context.l10n);
    final style = step == OnboardingV2Step.firstWallpaper
        ? OnboardingTypography.headline.copyWith(color: wallpaperColor)
        : OnboardingTypography.headline;
    return AnimatedPositioned(
      duration: context.motion(OnboardingMotion.normal),
      curve: OnboardingMotion.emphasized,
      top: OnboardingLayout.stepTitleY * sy,
      left: _headlineX(step) * sx,
      right: _headlineX(step) * sx,
      child: OnboardingStaggeredFade(
        delay: const Duration(milliseconds: 450),
        child: AnimatedSwitcher(
          duration: context.motion(OnboardingMotion.short),
          child: FittedBox(
            key: ValueKey(text),
            fit: BoxFit.scaleDown,
            child: Text(text, style: style, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.step,
    required this.sx,
    required this.sy,
    required this.state,
    required this.onCtaTap,
    required this.signingOut,
  });

  final OnboardingV2Step step;
  final double sx;
  final double sy;
  final OnboardingV2State state;
  final VoidCallback onCtaTap;

  /// "sign in again" is running the sign-out.
  final bool signingOut;

  @override
  Widget build(BuildContext context) {
    final saveFailed = onboardingSaveFailed(state);
    final isLoading = switch (step) {
      OnboardingV2Step.auth ||
      OnboardingV2Step.interests ||
      OnboardingV2Step.tasteQuiz ||
      OnboardingV2Step.starterPack => signingOut || (!saveFailed && state.actionStatus == ActionStatus.inProgress),
      OnboardingV2Step.aiGenerate =>
        signingOut ||
            (!saveFailed &&
                (state.aiData.status == AiGenerateStatus.loading || state.actionStatus == ActionStatus.inProgress)),
      OnboardingV2Step.firstWallpaper =>
        signingOut ||
            (!saveFailed &&
                (state.wallpaperData.status == FirstWallpaperStatus.loading ||
                    state.actionStatus == ActionStatus.inProgress)),
    };

    final isEnabled = switch (step) {
      OnboardingV2Step.auth || OnboardingV2Step.interests =>
        ((onboardingSaveFailed(state) && (state.sessionInvalid || state.completionFailed)) ||
            state.interestsData.canContinue),
      OnboardingV2Step.starterPack =>
        ((onboardingSaveFailed(state) && (state.sessionInvalid || state.completionFailed)) ||
            onboardingStarterPackShort(state) ||
            state.starterPackData.canContinue),
      OnboardingV2Step.tasteQuiz || OnboardingV2Step.aiGenerate || OnboardingV2Step.firstWallpaper => true,
    };

    final label = switch (step) {
      _ when onboardingSaveFailed(state) =>
        state.sessionInvalid ? context.l10n.onboardingSignInAgainLower : context.l10n.onboardingTryAgainLower,
      _ when onboardingStarterPackShort(state) => context.l10n.onboardingReloadLower,
      OnboardingV2Step.auth || OnboardingV2Step.interests => () {
        final selected = state.interestsData.selected.length;
        return selected < state.interestsData.requiredCount
            ? context.l10n.onboardingContinueSelected(selected)
            : context.l10n.onboardingContinue;
      }(),
      OnboardingV2Step.tasteQuiz || OnboardingV2Step.starterPack => context.l10n.onboardingContinue,
      OnboardingV2Step.aiGenerate => context.l10n.onboardingGenerateWallpaper,
      OnboardingV2Step.firstWallpaper =>
        defaultTargetPlatform == TargetPlatform.android
            ? context.l10n.onboardingSetWallpaper
            : context.l10n.onboardingSavePhotos,
    };

    return Positioned(
      top: OnboardingLayout.ctaY * sy,
      left: OnboardingLayout.ctaX * sx,
      right: OnboardingLayout.ctaX * sx,
      height: OnboardingLayout.ctaHeight * sy,
      child: OnboardingStaggeredFade(
        delay: const Duration(milliseconds: 750),
        child: OnboardingPrimaryButton(label: label, onPressed: onCtaTap, enabled: isEnabled, loading: isLoading),
      ),
    );
  }
}

class _BottomText extends StatelessWidget {
  const _BottomText({
    required this.step,
    required this.sy,
    this.wallpaperCategory,
    this.aiGenerateStatus,
    this.errorText,
    this.interestsRequired = OnboardingV2Config.minInterests,
    this.creatorCount = OnboardingV2Config.minFollows,
  });

  final OnboardingV2Step step;
  final double sy;
  final String? wallpaperCategory;
  final AiGenerateStatus? aiGenerateStatus;
  final int interestsRequired;
  final int creatorCount;

  /// Replaces the helper text while a save error needs the user's attention.
  final String? errorText;

  String _helperText(AppLocalizations l10n) => switch (step) {
    OnboardingV2Step.auth || OnboardingV2Step.interests =>
      interestsRequired == 0
          ? l10n.onboardingCategoriesUnavailable
          : l10n.onboardingSelectInterestMinimum(interestsRequired),
    OnboardingV2Step.starterPack =>
      creatorCount == 0
          ? l10n.onboardingCreatorsUnavailable
          : l10n.onboardingFollowCreatorMinimum(math.min(OnboardingV2Config.minFollows, creatorCount)),
    OnboardingV2Step.aiGenerate => switch (aiGenerateStatus) {
      AiGenerateStatus.success => l10n.onboardingGenerateSuccess,
      AiGenerateStatus.failure => l10n.onboardingGenerateFailure,
      _ => l10n.onboardingFirstAiWallpaper,
    },
    _ =>
      (wallpaperCategory != null && wallpaperCategory!.isNotEmpty)
          ? l10n.onboardingWallpaperForInterest(wallpaperCategory!)
          : l10n.onboardingWallpaperJustForYou,
  };

  @override
  Widget build(BuildContext context) {
    final text = errorText ?? _helperText(context.l10n);
    return AnimatedPositioned(
      duration: context.motion(OnboardingMotion.normal),
      curve: OnboardingMotion.emphasized,
      top: OnboardingLayout.helperY * sy,
      left: 0,
      right: 0,
      child: OnboardingStaggeredFade(
        delay: const Duration(milliseconds: 900),
        child: AnimatedSwitcher(
          duration: context.motion(OnboardingMotion.short),
          child: OnboardingHelperText(key: ValueKey(text), text: text),
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge({required this.sy, required this.color});

  final double sy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: OnboardingLayout.proBadgeY * sy,
      left: 0,
      right: 0,
      child: OnboardingStaggeredFade(
        delay: Duration.zero,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: OnboardingLayout.softenedBlurSigma,
                sigmaY: OnboardingLayout.softenedBlurSigma,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: OnboardingTypography.sans,
                      fontSize: 12,
                      height: 1.2,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text: context.l10n.onboardingPro,
                        style: TextStyle(decoration: TextDecoration.lineThrough, decorationThickness: 2.5),
                      ),
                      TextSpan(text: context.l10n.onboardingProFree),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
