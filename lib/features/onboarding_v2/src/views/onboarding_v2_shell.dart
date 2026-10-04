import 'dart:math' as math;
import 'dart:ui';

import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/audio/app_sound_manager.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/ai_target_size.dart';
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/status.dart';
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
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_staggered_fade.dart';
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

/// True when an onboarding save failed and the user must act on it.
bool _saveFailed(OnboardingV2State state) =>
    state.actionStatus == ActionStatus.failure &&
    (state.completionFailed || state.step == OnboardingV2Step.interests || state.step == OnboardingV2Step.starterPack);

String _saveErrorHelper(OnboardingV2State state) {
  if (state.sessionInvalid) return 'your session has expired. sign in again to continue';
  if (state.completionFailed) return "couldn't finish setup. check your connection and try again";
  return state.step == OnboardingV2Step.interests
      ? "couldn't save your picks. check your connection and try again"
      : "couldn't follow these creators. check your connection and try again";
}

String _saveErrorToast(OnboardingV2State state) {
  if (state.sessionInvalid) return 'Your session has expired. Please sign in again.';
  if (state.completionFailed) return "Couldn't finish setup. Try again.";
  return state.step == OnboardingV2Step.interests
      ? "Couldn't save your picks. Try again."
      : "Couldn't follow these creators. Try again.";
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
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool _imagesPrecached = false;
  bool _termsAccepted = false;
  bool _signingOut = false;

  static final _systemUiStyle = edgeToEdgeOverlayStyle(
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
  );

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
        statusBarIconBrightness: Brightness.dark,
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

  static const String _genericSignInError = 'Something went wrong, please try again!';

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
        toasts.error('Sign in cancelled.', haptic: false);
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
        toasts.error('Could not log out. Please try again.');
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
        toasts.error('Could not log out. Please try again.');
      }
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

  void _handleCtaTap(OnboardingV2Step step) {
    final state = _bloc.state;
    if (step != state.step) return;
    if (_signingOut || state.actionStatus == ActionStatus.inProgress) return;
    if (_saveFailed(state) && state.sessionInvalid) {
      _signInAgain();
      return;
    }
    if (_saveFailed(state) && state.completionFailed) {
      _bloc.add(const OnboardingV2Event.completionRetried());
      return;
    }
    if ((step == OnboardingV2Step.auth && state.isAuthLoading) ||
        (step == OnboardingV2Step.aiGenerate && state.aiData.status == AiGenerateStatus.loading) ||
        (step == OnboardingV2Step.firstWallpaper && state.wallpaperData.status == FirstWallpaperStatus.loading)) {
      return;
    }
    switch (step) {
      case OnboardingV2Step.auth:
        _handleGoogleSignIn();
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

  Widget _pageFor(OnboardingV2Step step) => KeyedSubtree(
    key: ValueKey(step),
    child: switch (step) {
      OnboardingV2Step.auth => const F0AuthPage(),
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
            listenWhen: (prev, curr) => !_saveFailed(prev) && _saveFailed(curr),
            listener: (context, state) => toasts.error(_saveErrorToast(state)),
          ),
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) =>
                curr.step == OnboardingV2Step.firstWallpaper &&
                prev.wallpaperData.status != curr.wallpaperData.status &&
                curr.wallpaperData.status == FirstWallpaperStatus.success,
            listener: (context, state) {
              if (state.navRequest == null) {
                toasts.success(defaultTargetPlatform == TargetPlatform.android ? 'Wallpaper set!' : 'Saved to Photos!');
                _bloc.add(const OnboardingV2Event.firstWallpaperStepContinued());
              }
            },
          ),
          BlocListener<OnboardingV2Bloc, OnboardingV2State>(
            listenWhen: (prev, curr) =>
                curr.step == OnboardingV2Step.aiGenerate &&
                prev.aiData.status != AiGenerateStatus.success &&
                curr.aiData.status == AiGenerateStatus.success,
            listener: (context, state) => _bloc.add(const OnboardingV2Event.aiGenerationStepContinued()),
          ),
        ],
        child: BlocConsumer<OnboardingV2Bloc, OnboardingV2State>(
          listenWhen: (prev, curr) => curr.navRequest != null && prev.navRequest != curr.navRequest,
          listener: (context, state) {
            if (state.navRequest != null) _handleNavRequest(context, state.navRequest!);
          },
          buildWhen: (prev, curr) =>
              prev.step != curr.step ||
              prev.isAuthLoading != curr.isAuthLoading ||
              prev.actionStatus != curr.actionStatus ||
              prev.sessionInvalid != curr.sessionInvalid ||
              prev.completionFailed != curr.completionFailed ||
              prev.interestsData.selected.length != curr.interestsData.selected.length ||
              prev.starterPackData.selectedEmails.length != curr.starterPackData.selectedEmails.length ||
              prev.wallpaperData.status != curr.wallpaperData.status ||
              prev.wallpaperData.wallpaper?.thumbnailUrl != curr.wallpaperData.wallpaper?.thumbnailUrl ||
              prev.aiData != curr.aiData,
          builder: (context, state) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _systemUiStyle,
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (_signingOut) return;
                  _bloc.add(const OnboardingV2Event.stepBack());
                },
                child: Material(
                  color: OnboardingColors.fallbackFill,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Layer 0: animated background (blur + image cross-fade), isolated in a
                      // RepaintBoundary from page content and overlay layers.
                      RepaintBoundary(
                        child: OnboardingStepBackground(
                          step: state.step,
                          wallpaperUrl: state.wallpaperData.wallpaper?.fullUrl,
                        ),
                      ),

                      // Layer 1: unique page content — fades between steps.
                      AnimatedSwitcher(
                        duration: context.motion(const Duration(milliseconds: 300)),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
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
                          legalTap: _legalTap,
                          onCtaTap: () => _handleCtaTap(state.step),
                          onAppleTap: _handleAppleSignIn,
                          termsAccepted: _termsAccepted,
                          onTermsChanged: _setTermsAccepted,
                          onBrowseTap: _handleBrowseWithoutAccount,
                          signingOut: _signingOut,
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

/// Shared elements (headline, progress, button, helper text) that persist across all steps.
class _SharedOverlay extends StatefulWidget {
  const _SharedOverlay({
    required this.state,
    required this.legalTap,
    required this.onCtaTap,
    required this.onAppleTap,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.onBrowseTap,
    required this.signingOut,
  });

  final OnboardingV2State state;
  final TapGestureRecognizer legalTap;
  final VoidCallback onCtaTap;
  final VoidCallback onAppleTap;
  final bool termsAccepted;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onBrowseTap;
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
              onAppleTap: widget.onAppleTap,
              termsAccepted: widget.termsAccepted,
              onTermsChanged: widget.onTermsChanged,
              legalTap: widget.legalTap,
              onBrowseTap: widget.onBrowseTap,
              signingOut: widget.signingOut,
            ),
            _BottomText(
              step: step,
              sy: sy,
              legalTap: widget.legalTap,
              termsAccepted: widget.termsAccepted,
              onTermsChanged: widget.onTermsChanged,
              wallpaperCategory: widget.state.wallpaperData.wallpaper?.sourceCategory,
              aiGenerateStatus: widget.state.aiData.status,
              errorText: _saveFailed(widget.state) ? _saveErrorHelper(widget.state) : null,
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
      child: AnimatedOpacity(
        duration: OnboardingMotion.normal,
        opacity: step == OnboardingV2Step.auth ? 0.0 : 1.0,
        child: Center(
          child: Transform.scale(
            scaleX: sx,
            scaleY: sy,
            alignment: Alignment.topCenter,
            child: OnboardingProgressIndicator(step: progressStep, totalSteps: 4, color: color),
          ),
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

  static double _headlineY(OnboardingV2Step step) =>
      step == OnboardingV2Step.auth ? OnboardingLayout.welcomeHeadlineY : OnboardingLayout.stepTitleY;

  static double _headlineX(OnboardingV2Step step) => switch (step) {
    // Auth: no horizontal constraint — the explicit \n is the only line break.
    // Applying padding here would squeeze "Your screen," onto a second line.
    OnboardingV2Step.auth => 0,
    OnboardingV2Step.interests => OnboardingLayout.interestsTitleX,
    OnboardingV2Step.starterPack => OnboardingLayout.starterPackTitleX,
    OnboardingV2Step.aiGenerate => OnboardingLayout.aiTitleX,
    OnboardingV2Step.firstWallpaper => OnboardingLayout.aiTitleX,
  };

  static String _headlineText(OnboardingV2Step step) => switch (step) {
    OnboardingV2Step.auth => 'Your screen,\nreimagined.',
    OnboardingV2Step.interests => 'Pick your vibe',
    OnboardingV2Step.starterPack => 'Find your people',
    OnboardingV2Step.aiGenerate => 'Create your\nfirst wallpaper',
    OnboardingV2Step.firstWallpaper => 'Make it yours',
  };

  @override
  Widget build(BuildContext context) {
    final text = _headlineText(step);
    final style = step == OnboardingV2Step.firstWallpaper
        ? OnboardingTypography.headline.copyWith(color: wallpaperColor)
        : OnboardingTypography.headline;
    return AnimatedPositioned(
      duration: OnboardingMotion.normal,
      curve: OnboardingMotion.emphasized,
      top: _headlineY(step) * sy,
      left: _headlineX(step) * sx,
      right: _headlineX(step) * sx,
      child: OnboardingStaggeredFade(
        delay: const Duration(milliseconds: 450),
        child: AnimatedSwitcher(
          duration: OnboardingMotion.short,
          child: Text(key: ValueKey(text), text, style: style, textAlign: TextAlign.center),
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
    required this.onAppleTap,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.legalTap,
    required this.onBrowseTap,
    required this.signingOut,
  });

  final OnboardingV2Step step;
  final double sx;
  final double sy;
  final OnboardingV2State state;
  final VoidCallback onCtaTap;
  final VoidCallback onAppleTap;

  /// "I agree to the Terms of Use" gate — Google, Apple and the guest button
  /// all stay disabled until this is ticked.
  final bool termsAccepted;
  final ValueChanged<bool> onTermsChanged;
  final TapGestureRecognizer legalTap;

  /// iOS-only guest entry point (Guideline 5.1.1(v)).
  final VoidCallback onBrowseTap;

  final bool signingOut;

  @override
  Widget build(BuildContext context) {
    final saveFailed = _saveFailed(state);
    final isLoading = switch (step) {
      OnboardingV2Step.auth =>
        signingOut || (!saveFailed && (state.isAuthLoading || state.actionStatus == ActionStatus.inProgress)),
      OnboardingV2Step.interests ||
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
      OnboardingV2Step.auth =>
        (_saveFailed(state) && (state.sessionInvalid || state.completionFailed)) || termsAccepted,
      OnboardingV2Step.interests =>
        ((_saveFailed(state) && (state.sessionInvalid || state.completionFailed)) || state.interestsData.canContinue),
      OnboardingV2Step.starterPack =>
        ((_saveFailed(state) && (state.sessionInvalid || state.completionFailed)) || state.starterPackData.canContinue),
      OnboardingV2Step.aiGenerate => true,
      OnboardingV2Step.firstWallpaper => true,
    };

    final label = switch (step) {
      _ when _saveFailed(state) => state.sessionInvalid ? 'sign in again' : 'try again',
      OnboardingV2Step.auth => 'Continue with Google',
      OnboardingV2Step.interests => () {
        final selected = state.interestsData.selected.length;
        return selected < OnboardingV2Config.minInterests ? 'continue ($selected selected)' : 'continue';
      }(),
      OnboardingV2Step.starterPack => 'continue',
      OnboardingV2Step.aiGenerate => 'generate my wallpaper',
      OnboardingV2Step.firstWallpaper =>
        defaultTargetPlatform == TargetPlatform.android ? 'set as wallpaper' : 'save to photos',
    };

    final bool isAuthStep = step == OnboardingV2Step.auth;
    // Apple sign-in and guest browsing are iOS-only: Android keeps mandatory Google sign-in.
    final bool showIosAuthExtras = isAuthStep && defaultTargetPlatform == TargetPlatform.iOS && !_saveFailed(state);
    const double browseRowHeight = 36;
    final double extraHeight = showIosAuthExtras ? (OnboardingLayout.ctaHeight + 12) * sy + browseRowHeight * sy : 0.0;
    // Buttons stay at most 480 pt wide, centered, so a tablet does not stretch them edge to edge.
    final double side = math.max(OnboardingLayout.ctaX * sx, (MediaQuery.sizeOf(context).width - 480) / 2);
    return Positioned(
      top: OnboardingLayout.ctaY * sy - extraHeight,
      left: side,
      right: side,
      height: OnboardingLayout.ctaHeight * sy + extraHeight,
      child: OnboardingStaggeredFade(
        delay: const Duration(milliseconds: 750),
        child: Stack(
          children: [
            Column(
              children: [
                if (showIosAuthExtras) ...[
                  Expanded(
                    child: OnboardingPrimaryButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple,
                      onPressed: onAppleTap,
                      enabled: isEnabled,
                      loading: isLoading,
                    ),
                  ),
                  SizedBox(height: 12 * sy),
                ],
                Expanded(
                  child: OnboardingPrimaryButton(
                    label: label,
                    onPressed: onCtaTap,
                    enabled: isEnabled,
                    loading: isLoading,
                  ),
                ),
                if (showIosAuthExtras)
                  SizedBox(
                    height: browseRowHeight * sy,
                    child: Center(
                      child: TextButton(
                        onPressed: termsAccepted && !signingOut && state.actionStatus != ActionStatus.inProgress
                            ? () {
                                PrismHaptics.tap();
                                onBrowseTap();
                              }
                            : null,
                        child: Text(
                          'Browse without an account',
                          style: OnboardingTypography.helper.copyWith(
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Disabled buttons swallow taps silently; say why instead.
            if (isAuthStep && !termsAccepted && !_saveFailed(state))
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => toasts.error('Please agree to the Terms of Use first.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TermsCheckboxRow extends StatelessWidget {
  const _TermsCheckboxRow({required this.accepted, required this.onChanged, required this.legalTap, super.key});

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final TapGestureRecognizer legalTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        PrismHaptics.selection();
        onChanged(!accepted);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: accepted,
              onChanged: (value) {
                PrismHaptics.selection();
                onChanged(value ?? false);
              },
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? OnboardingColors.buttonBackground
                    : OnboardingColors.transparent,
              ),
              checkColor: OnboardingColors.buttonText,
              side: const BorderSide(color: OnboardingColors.textOnDark),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: OnboardingTypography.helper,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Use',
                    style: OnboardingTypography.helper.copyWith(decoration: TextDecoration.underline),
                    recognizer: legalTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomText extends StatelessWidget {
  const _BottomText({
    required this.step,
    required this.sy,
    required this.legalTap,
    required this.termsAccepted,
    required this.onTermsChanged,
    this.wallpaperCategory,
    this.aiGenerateStatus,
    this.errorText,
  });

  final OnboardingV2Step step;
  final double sy;
  final TapGestureRecognizer legalTap;
  final bool termsAccepted;
  final ValueChanged<bool> onTermsChanged;
  final String? wallpaperCategory;
  final AiGenerateStatus? aiGenerateStatus;

  final String? errorText;

  String _helperText() => switch (step) {
    OnboardingV2Step.interests =>
      'select at least ${OnboardingV2Config.minInterests} categories to personalize your feed',
    OnboardingV2Step.starterPack => 'we are suggesting you follow these ${OnboardingV2Config.minFollows} creators',
    OnboardingV2Step.aiGenerate => switch (aiGenerateStatus) {
      AiGenerateStatus.success => 'looking good! tap "use this wallpaper" to continue',
      AiGenerateStatus.failure => 'something went wrong — tap generate to try again',
      _ => 'your first wallpaper, generated by AI',
    },
    _ =>
      (wallpaperCategory != null && wallpaperCategory!.isNotEmpty)
          ? 'we picked this wallpaper based on your interest in $wallpaperCategory'
          : 'we picked this wallpaper just for you',
  };

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (step == OnboardingV2Step.auth && errorText == null) {
      content = _TermsCheckboxRow(
        key: const ValueKey('legal'),
        accepted: termsAccepted,
        onChanged: onTermsChanged,
        legalTap: legalTap,
      );
    } else {
      final text = errorText ?? _helperText();
      content = OnboardingHelperText(key: ValueKey(text), text: text);
    }

    return AnimatedPositioned(
      duration: OnboardingMotion.normal,
      curve: OnboardingMotion.emphasized,
      top: OnboardingLayout.helperY * sy,
      left: 0,
      right: 0,
      child: OnboardingStaggeredFade(
        delay: const Duration(milliseconds: 900),
        child: AnimatedSwitcher(duration: OnboardingMotion.short, child: content),
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
                    children: const [
                      TextSpan(
                        text: 'PRO',
                        style: TextStyle(decoration: TextDecoration.lineThrough, decorationThickness: 2.5),
                      ),
                      TextSpan(text: '  →  free for you'),
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
