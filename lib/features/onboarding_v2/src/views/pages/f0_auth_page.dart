import 'dart:io';
import 'dart:math' as math;

import 'package:Prism/auth/apple_auth.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class F0AuthPage extends StatefulWidget {
  const F0AuthPage({super.key});

  @override
  State<F0AuthPage> createState() => _F0AuthPageState();
}

class _F0AuthPageState extends State<F0AuthPage> with SingleTickerProviderStateMixin {
  final AppleAuth _appleAuth = AppleAuth();
  late AnimationController _controller;
  String? _loadingProvider;

  // Staggered entrance animations
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _headlineFade;
  late Animation<Offset> _headlineSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _termsFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    // Logo & step pill: slide from top + fade
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.6), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
      ),
    );

    // Headline: slide from left + fade
    _headlineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
    );
    _headlineSlide = Tween<Offset>(begin: const Offset(-0.15, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // Subtitle: fade only
    _subtitleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );

    // Buttons: slide from bottom + fade
    _buttonsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
    _buttonsSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutBack),
      ),
    );

    // Terms: fade
    _termsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _loadingProvider = 'apple');
    final bloc = context.read<OnboardingV2Bloc>();
    bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: true));
    try {
      final result = await _appleAuth.signInWithApple();
      if (!mounted) return;
      if (result == AppleAuth.signInCancelledResult) {
        app_state.prismUser.loggedIn = false;
        app_state.persistPrismUser();
        toasts.codeSend('Sign in cancelled.');
        setState(() => _loadingProvider = null);
        bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
      } else {
        app_state.prismUser.loggedIn = true;
        app_state.persistPrismUser();
        toasts.codeSend('Login Successful!');
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() => _loadingProvider = null);
        bloc.add(const OnboardingV2Event.authCompleted());
      }
    } catch (e, st) {
      logger.e('Apple sign-in failed', tag: 'OnboardingV2', error: e, stackTrace: st);
      app_state.prismUser.loggedIn = false;
      app_state.persistPrismUser();
      if (mounted) {
        setState(() => _loadingProvider = null);
        toasts.error('Something went wrong, please try again!');
      }
      bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loadingProvider = 'google');
    final bloc = context.read<OnboardingV2Bloc>();
    bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: true));
    try {
      final result = await app_state.gAuth.signInWithGoogle();
      if (!mounted) return;
      if (result == GoogleAuth.signInCancelledResult) {
        app_state.prismUser.loggedIn = false;
        app_state.persistPrismUser();
        toasts.codeSend('Sign in cancelled.');
        setState(() => _loadingProvider = null);
        bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
      } else {
        app_state.prismUser.loggedIn = true;
        app_state.persistPrismUser();
        toasts.codeSend('Login Successful!');
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() => _loadingProvider = null);
        bloc.add(const OnboardingV2Event.authCompleted());
      }
    } catch (e, st) {
      logger.e('Google sign-in failed', tag: 'OnboardingV2', error: e, stackTrace: st);
      app_state.prismUser.loggedIn = false;
      app_state.persistPrismUser();
      if (mounted) {
        setState(() => _loadingProvider = null);
        toasts.error('Something went wrong, please try again!');
      }
      bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isAnyLoading = _loadingProvider != null;
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.isAuthLoading != curr.isAuthLoading,
      builder: (context, state) {
        final isOverlayVisible = state.isAuthLoading;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              Image.asset('assets/images/first.png', fit: BoxFit.cover),

              // 4-stop gradient overlay for depth
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x40000000), Color(0xCC000000), Color(0xFF000000)],
                    stops: [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),

              // Subtle rose-pink radial glow near headline area
              Positioned(
                bottom: 220,
                left: -60,
                right: -60,
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.centerLeft,
                      radius: 0.85,
                      colors: [primary.withValues(alpha: 0.18), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar: logo + step pill
                    FadeTransition(
                      opacity: _logoFade,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Prism',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  shadows: [Shadow(color: primary.withValues(alpha: 0.4), blurRadius: 12)],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primary.withValues(alpha: 0.4), width: 1),
                                ),
                                child: const Text(
                                  'Step 1 of 4',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Headline
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeTransition(
                            opacity: _headlineFade,
                            child: SlideTransition(
                              position: _headlineSlide,
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.5,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Curate your\n'),
                                    TextSpan(
                                      text: 'digital space.',
                                      style: TextStyle(
                                        color: primary,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        shadows: [Shadow(color: primary.withValues(alpha: 0.5), blurRadius: 20)],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Subtitle
                          FadeTransition(
                            opacity: _subtitleFade,
                            child: const Text(
                              'Access thousands of premium wallpapers\ncreated by top digital artists.',
                              style: TextStyle(color: Color(0x99FFFFFF), fontSize: 15, height: 1.6),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Auth buttons
                          FadeTransition(
                            opacity: _buttonsFade,
                            child: SlideTransition(
                              position: _buttonsSlide,
                              child: Column(
                                children: [
                                  if (Platform.isIOS || Platform.isMacOS) ...[
                                    _AuthButton(
                                      onTap: isAnyLoading ? null : _handleAppleSignIn,
                                      label: 'Continue with Apple',
                                      isLoading: _loadingProvider == 'apple',
                                      child: const Icon(Icons.apple, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _AuthButton(
                                    onTap: isAnyLoading ? null : _handleGoogleSignIn,
                                    label: 'Continue with Google',
                                    isLoading: _loadingProvider == 'google',
                                    child: const _GoogleIcon(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Terms
                          FadeTransition(
                            opacity: _termsFade,
                            child: Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  children: [
                                    const TextSpan(text: 'By continuing you agree to our '),
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => launchUrl(
                                          Uri.parse('https://prism-app-terms.web.app'),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Full-page loading overlay — blocks accidental taps during auth
              if (isOverlayVisible)
                AnimatedOpacity(
                  opacity: isOverlayVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Auth Button ──────────────────────────────────────────────────────────────

class _AuthButton extends StatefulWidget {
  const _AuthButton({required this.onTap, required this.label, required this.child, this.isLoading = false});

  final VoidCallback? onTap;
  final String label;
  final Widget child;
  final bool isLoading;

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    setState(() => _scale = 0.97);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onTap?.call();
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
              boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 1)],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: widget.isLoading
                ? const Center(child: _PulsingDotsLoader())
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      widget.child,
                      const SizedBox(width: 10),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Pulsing Dots Loader ───────────────────────────────────────────────────────

class _PulsingDotsLoader extends StatefulWidget {
  const _PulsingDotsLoader();

  @override
  State<_PulsingDotsLoader> createState() => _PulsingDotsLoaderState();
}

class _PulsingDotsLoaderState extends State<_PulsingDotsLoader> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    // Stagger start of each dot
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 130), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FadeTransition(
              opacity: _animations[i],
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Google "G" Icon ───────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleGPainter()));
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Red arc: top-right quadrant area
    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.butt;

    // Blue arc: top-left
    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.butt;

    // Green arc: bottom
    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.butt;

    // Yellow arc: bottom-right
    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.butt;

    // Shrink rect slightly for stroke to stay within bounds
    final innerRect = rect.deflate(size.width * 0.11);

    // Draw the 4 color arcs of Google "G" ring
    // Blue: top-left arc (~225° → 360°+45°)
    canvas.drawArc(innerRect, math.pi * 1.25, math.pi * 0.75, false, paintBlue);
    // Red: top-right arc (~315° → 45°) wrapping around top
    canvas.drawArc(innerRect, math.pi * 1.75, math.pi * 0.5, false, paintRed);
    // Yellow: bottom-right arc (~45° → 135°)
    canvas.drawArc(innerRect, math.pi * 0.25, math.pi * 0.4, false, paintYellow);
    // Green: bottom arc (~135° → 225°)
    canvas.drawArc(innerRect, math.pi * 0.65, math.pi * 0.6, false, paintGreen);

    // Draw the horizontal "G" crossbar
    final crossbarPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.round;

    final crossbarY = center.dy;
    final crossbarStart = center.dx;
    final crossbarEnd = center.dx + radius * 0.85;
    canvas.drawLine(Offset(crossbarStart, crossbarY), Offset(crossbarEnd, crossbarY), crossbarPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
