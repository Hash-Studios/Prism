import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/apple_auth.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/showUp.dart';
import 'package:Prism/features/startup/services/tomorrow_hook_service.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController onboardingCarouselController = PageController();
  int? _currentPage;
  Color? selectedAccentColor;
  int? selectedTheme;
  late bool isLoading;
  bool? isSignedIn;
  final AppleAuth _appleAuth = AppleAuth();
  Image? image1;
  Image? image2;
  Image? image3;
  int? _lastTrackedStep;
  bool _completingOnboarding = false;

  void _trackOnboardingStepViewed(int step) {
    if (_lastTrackedStep == step) {
      return;
    }
    _lastTrackedStep = step;
    analytics.track(OnboardingStepViewedEvent(step: step));
  }

  void _trackOnboardingAction(AnalyticsActionValue action) {
    analytics.track(OnboardingActionTappedEvent(step: (_currentPage ?? 0) + 1, action: action));
  }

  void _trackOnboardingAuthResult({
    required EventResultValue result,
    AnalyticsReasonValue? reason,
    AuthMethodValue method = AuthMethodValue.google,
  }) {
    analytics.track(OnboardingAuthResultEvent(method: method, result: result, reason: reason));
  }

  Future<void> _completeOnboardingToSplash() async {
    if (_completingOnboarding) {
      return;
    }
    _completingOnboarding = true;
    try {
      main.prefs.put('onboarded_new', true);
      await TomorrowHookService.instance.maybeRunTomorrowHookAtOnboardingDone(context);
      if (!mounted) {
        return;
      }
      context.router.replaceAll(<PageRouteInfo>[const SplashWidgetRoute()]);
    } finally {
      _completingOnboarding = false;
    }
  }

  Future<void> _handleAppleSignIn() async {
    _trackOnboardingAction(AnalyticsActionValue.signInTapped);
    logger.i('Apple sign in tapped', tag: 'Onboarding');
    setState(() {
      isLoading = true;
    });
    try {
      final String signInResult = await _appleAuth.signInWithApple();
      if (signInResult == AppleAuth.signInCancelledResult) {
        _trackOnboardingAuthResult(
          result: EventResultValue.cancelled,
          reason: AnalyticsReasonValue.userCancelled,
          method: AuthMethodValue.apple,
        );
        app_state.prismUser.loggedIn = false;
        app_state.persistPrismUser();
        toasts.codeSend("Sign in cancelled.");
      } else {
        _trackOnboardingAuthResult(result: EventResultValue.success, method: AuthMethodValue.apple);
        toasts.codeSend("Login Successful!");
        app_state.prismUser.loggedIn = true;
        app_state.persistPrismUser();
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        main.prefs.put('onboarded_new', true);
        context.router.replace(
          OptionalInfo3Route(
            heading: 'Follow top creators',
            subheading: 'Never miss the latest and greatest',
            showSkip: false,
            skipText: "Skip",
            doneText: "DONE",
          ),
        );
      }
    } catch (e, st) {
      logger.e('Apple sign-in failed', tag: 'Onboarding', error: e, stackTrace: st);
      _trackOnboardingAuthResult(
        result: EventResultValue.failure,
        reason: AnalyticsReasonValue.error,
        method: AuthMethodValue.apple,
      );
      app_state.prismUser.loggedIn = false;
      app_state.persistPrismUser();
      toasts.error("Something went wrong, please try again!");
    }
    setState(() {
      isLoading = false;
      isSignedIn = app_state.prismUser.loggedIn;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(image1!.image, context);
    precacheImage(image2!.image, context);
    precacheImage(image3!.image, context);
  }

  @override
  void initState() {
    image1 = Image.asset('assets/images/first.png');
    image2 = Image.asset('assets/images/second.png');
    image3 = Image.asset('assets/images/third.png');
    super.initState();
    isLoading = false;
    isSignedIn = app_state.prismUser.loggedIn;
    selectedTheme = 2;
    selectedAccentColor = const Color(0xFFE57697);
    _currentPage = 0;
    _trackOnboardingStepViewed(1);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onboardingCarouselController.previousPage(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE57697),
        body: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView(
                controller: onboardingCarouselController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                  _trackOnboardingStepViewed(page + 1);
                },
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(padding: const EdgeInsets.fromLTRB(0, 110, 0, 8), child: image1),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: Duration(milliseconds: 150),
                            child: Text(
                              'Welcome to Prism!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: 17),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.0),
                            child: ShowUpTransition(
                              forward: true,
                              slideSide: SlideFromSlide.bottom,
                              delay: Duration(milliseconds: 200),
                              child: Text(
                                'The Next Level in customisation!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontFamily: "Roboto",
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 179),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(padding: const EdgeInsets.fromLTRB(0, 110, 0, 8), child: image2),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: Duration(milliseconds: 150),
                            child: Text(
                              'Customise your experience!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 17),
                          ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: const Duration(milliseconds: 200),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.935,
                              height: MediaQuery.of(context).size.height * 0.07,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: MaterialButton(
                                        color: Theme.of(context).hintColor,
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          context.setPrismThemeMode("Light");

                                          setState(() {
                                            selectedTheme = 1;
                                          });
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: MediaQuery.of(context).size.width * 0.27,
                                              height: MediaQuery.of(context).size.height * 0.06,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.black12),
                                                borderRadius: BorderRadius.circular(5),
                                                color: Colors.white,
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.all(4.0),
                                                    child: Text(
                                                      "Light",
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.titleSmall!.copyWith(color: Colors.black),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selectedTheme == 1)
                                              Container(
                                                width: MediaQuery.of(context).size.width * 0.27,
                                                height: MediaQuery.of(context).size.height * 0.06,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                  border: Border.all(color: Colors.black45),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: const Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [Icon(JamIcons.check, color: Colors.white)],
                                                ),
                                              )
                                            else
                                              Container(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: MaterialButton(
                                        color: Theme.of(context).hintColor,
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          context.setPrismThemeMode("Dark");
                                          setState(() {
                                            selectedTheme = 2;
                                          });
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: MediaQuery.of(context).size.width * 0.27,
                                              height: MediaQuery.of(context).size.height * 0.06,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.black12),
                                                borderRadius: BorderRadius.circular(5),
                                                color: Colors.black,
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.all(4.0),
                                                    child: Text(
                                                      "Dark",
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.titleSmall!.copyWith(color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selectedTheme == 2)
                                              Container(
                                                width: MediaQuery.of(context).size.width * 0.27,
                                                height: MediaQuery.of(context).size.height * 0.06,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.5),
                                                  border: Border.all(color: Colors.black45),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: const Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [Icon(JamIcons.check, color: Colors.black)],
                                                ),
                                              )
                                            else
                                              Container(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: MaterialButton(
                                        color: Theme.of(context).hintColor,
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          context.setPrismThemeMode("System");
                                          setState(() {
                                            selectedTheme = 3;
                                          });
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: MediaQuery.of(context).size.width * 0.27,
                                              height: MediaQuery.of(context).size.height * 0.06,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.black12),
                                                borderRadius: BorderRadius.circular(5),
                                                color: MediaQuery.of(context).platformBrightness == Brightness.dark
                                                    ? Colors.black
                                                    : Colors.white,
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.all(4.0),
                                                    child: Text(
                                                      "System",
                                                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                                        color:
                                                            MediaQuery.of(context).platformBrightness == Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selectedTheme == 3)
                                              Container(
                                                width: MediaQuery.of(context).size.width * 0.27,
                                                height: MediaQuery.of(context).size.height * 0.06,
                                                decoration: BoxDecoration(
                                                  color: MediaQuery.of(context).platformBrightness == Brightness.dark
                                                      ? Colors.white.withValues(alpha: 0.5)
                                                      : Colors.black.withValues(alpha: 0.5),
                                                  border: Border.all(color: Colors.black45),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      JamIcons.check,
                                                      color:
                                                          MediaQuery.of(context).platformBrightness == Brightness.dark
                                                          ? Colors.black
                                                          : Colors.white,
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Container(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 17),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.0),
                            child: ShowUpTransition(
                              forward: true,
                              slideSide: SlideFromSlide.bottom,
                              delay: Duration(milliseconds: 250),
                              child: Text(
                                'These preferences will enhance your experience. You can always change these later.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontFamily: "Roboto",
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 92),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(padding: const EdgeInsets.fromLTRB(0, 110, 0, 8), child: image3),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const ShowUpTransition(
                            forward: true,
                            slideSide: SlideFromSlide.bottom,
                            delay: Duration(milliseconds: 150),
                            child: Text(
                              'Sign in to Continue',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 17),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.0),
                            child: ShowUpTransition(
                              forward: true,
                              slideSide: SlideFromSlide.bottom,
                              delay: Duration(milliseconds: 200),
                              child: Text(
                                'Sign in to save & sync your data!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontFamily: "Roboto",
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (Platform.isIOS || Platform.isMacOS)
                            ShowUpTransition(
                              forward: true,
                              slideSide: SlideFromSlide.bottom,
                              delay: const Duration(milliseconds: 250),
                              child: GestureDetector(
                                onTap: isLoading ? null : _handleAppleSignIn,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 40),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(500),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.apple, color: Colors.white, size: 22),
                                      SizedBox(width: 10),
                                      Text(
                                        'Continue with Apple',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontFamily: "Roboto",
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: _currentPage != 2
                            ? () {
                                _trackOnboardingAction(AnalyticsActionValue.skipTapped);
                                onboardingCarouselController.animateToPage(
                                  2,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            : () {
                                _trackOnboardingAction(AnalyticsActionValue.finishTapped);
                                unawaited(_completeOnboardingToSplash());
                              },
                        style: ButtonStyle(overlayColor: WidgetStateColor.resolveWith((states) => Colors.white10)),
                        child: SizedBox(
                          width: 75,
                          child: Text(
                            _currentPage == 2 ? "Finish" : "Skip",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontFamily: "Roboto",
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      _OBIndicator(currentPage: _currentPage),
                      ElevatedButton(
                        onPressed: _currentPage != 2
                            ? () {
                                _trackOnboardingAction(AnalyticsActionValue.nextTapped);
                                onboardingCarouselController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            : isSignedIn!
                            ? () {
                                _trackOnboardingAction(AnalyticsActionValue.signInTapped);
                                _trackOnboardingAuthResult(
                                  result: EventResultValue.ignored,
                                  reason: AnalyticsReasonValue.alreadySignedIn,
                                );
                                toasts.codeSend("Already signed-in!");
                              }
                            : isLoading
                            ? () {}
                            : () async {
                                _trackOnboardingAction(AnalyticsActionValue.signInTapped);
                                logger.i('Sign in tapped', tag: 'Onboarding');
                                setState(() {
                                  isLoading = true;
                                });
                                try {
                                  final String signInResult = await app_state.gAuth.signInWithGoogle();
                                  if (signInResult == GoogleAuth.signInCancelledResult) {
                                    _trackOnboardingAuthResult(
                                      result: EventResultValue.cancelled,
                                      reason: AnalyticsReasonValue.userCancelled,
                                    );
                                    app_state.prismUser.loggedIn = false;
                                    app_state.persistPrismUser();
                                    toasts.codeSend("Sign in cancelled.");
                                  } else {
                                    _trackOnboardingAuthResult(result: EventResultValue.success);
                                    toasts.codeSend("Login Successful!");
                                    app_state.prismUser.loggedIn = true;
                                    app_state.persistPrismUser();
                                    await Future.delayed(const Duration(milliseconds: 500));
                                    if (!context.mounted) {
                                      return;
                                    }
                                    main.prefs.put('onboarded_new', true);
                                    context.router.replace(
                                      OptionalInfo3Route(
                                        heading: 'Follow top creators',
                                        subheading: 'Never miss the latest and greatest',
                                        showSkip: false,
                                        skipText: "Skip",
                                        doneText: "DONE",
                                      ),
                                    );
                                  }
                                } catch (e, st) {
                                  logger.e('Google sign-in failed', tag: 'Onboarding', error: e, stackTrace: st);
                                  _trackOnboardingAuthResult(
                                    result: EventResultValue.failure,
                                    reason: AnalyticsReasonValue.error,
                                  );
                                  app_state.prismUser.loggedIn = false;
                                  app_state.persistPrismUser();
                                  toasts.error("Something went wrong, please try again!");
                                }
                                setState(() {
                                  isLoading = false;
                                  isSignedIn = app_state.prismUser.loggedIn;
                                });
                              },
                        style: ButtonStyle(backgroundColor: WidgetStateColor.resolveWith((states) => Colors.white)),
                        child: SizedBox(
                          width: 60,
                          child: _currentPage != 2
                              ? Text(
                                  _currentPage == 0
                                      ? 'NEXT'
                                      : _currentPage == 1
                                      ? 'NEXT'
                                      : 'SIGN IN',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE57697),
                                    fontSize: 15,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : isSignedIn!
                              ? const Icon(JamIcons.check, color: Color(0xFFE57697))
                              : isLoading
                              ? const Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE57697)),
                                    ),
                                  ),
                                )
                              : Text(
                                  _currentPage == 0
                                      ? 'NEXT'
                                      : _currentPage == 1
                                      ? 'NEXT'
                                      : 'SIGN IN',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE57697),
                                    fontSize: 15,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OBIndicator extends StatelessWidget {
  const _OBIndicator({required int? currentPage}) : _currentPage = currentPage;

  final int? _currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [0, 1, 2].map((i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: _currentPage == i ? 12.0 : 7.0,
          height: 7.0,
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(500),
            color: _currentPage == i ? Colors.white : Colors.white38,
          ),
        );
      }).toList(),
    );
  }
}
