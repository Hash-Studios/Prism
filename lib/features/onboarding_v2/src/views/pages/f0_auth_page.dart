import 'dart:io';

import 'package:Prism/auth/apple_auth.dart';
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

class _F0AuthPageState extends State<F0AuthPage> {
  final AppleAuth _appleAuth = AppleAuth();

  Future<void> _handleAppleSignIn() async {
    final bloc = context.read<OnboardingV2Bloc>();
    bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: true));
    try {
      final result = await _appleAuth.signInWithApple();
      if (!mounted) return;
      if (result == AppleAuth.signInCancelledResult) {
        app_state.prismUser.loggedIn = false;
        app_state.persistPrismUser();
        toasts.codeSend('Sign in cancelled.');
        bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
      } else {
        app_state.prismUser.loggedIn = true;
        app_state.persistPrismUser();
        toasts.codeSend('Login Successful!');
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        bloc.add(const OnboardingV2Event.authCompleted());
      }
    } catch (e, st) {
      logger.e('Apple sign-in failed', tag: 'OnboardingV2', error: e, stackTrace: st);
      app_state.prismUser.loggedIn = false;
      app_state.persistPrismUser();
      if (mounted) toasts.error('Something went wrong, please try again!');
      bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final bloc = context.read<OnboardingV2Bloc>();
    bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: true));
    try {
      final result = await app_state.gAuth.signInWithGoogle();
      if (!mounted) return;
      if (result == 'cancelled') {
        app_state.prismUser.loggedIn = false;
        app_state.persistPrismUser();
        toasts.codeSend('Sign in cancelled.');
        bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
      } else {
        app_state.prismUser.loggedIn = true;
        app_state.persistPrismUser();
        toasts.codeSend('Login Successful!');
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        bloc.add(const OnboardingV2Event.authCompleted());
      }
    } catch (e, st) {
      logger.e('Google sign-in failed', tag: 'OnboardingV2', error: e, stackTrace: st);
      app_state.prismUser.loggedIn = false;
      app_state.persistPrismUser();
      if (mounted) toasts.error('Something went wrong, please try again!');
      bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.isAuthLoading != curr.isAuthLoading,
      builder: (context, state) {
        final isLoading = state.isAuthLoading;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/first.png', fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x80000000), Color(0xCC000000)],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Prism',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Step 1 of 4',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                              children: [
                                const TextSpan(text: 'Curate your\n'),
                                TextSpan(
                                  text: 'digital space.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Access thousands of premium wallpapers\ncreated by top digital artists.',
                            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 40),
                          if (Platform.isIOS || Platform.isMacOS)
                            _AuthButton(
                              onTap: isLoading ? null : _handleAppleSignIn,
                              icon: Icons.apple,
                              label: 'Continue with Apple',
                              isLoading: isLoading,
                            ),
                          if (Platform.isIOS || Platform.isMacOS) const SizedBox(height: 12),
                          _AuthButton(
                            onTap: isLoading ? null : _handleGoogleSignIn,
                            icon: null,
                            label: 'Continue with Google',
                            isLoading: (Platform.isAndroid) && isLoading,
                            useGoogleIcon: true,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                                children: [
                                  const TextSpan(text: 'By continuing you agree to our '),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: const TextStyle(color: Colors.white54, decoration: TextDecoration.underline),
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
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.onTap,
    required this.label,
    this.icon,
    this.useGoogleIcon = false,
    this.isLoading = false,
  });

  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final bool useGoogleIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 10)],
                      if (useGoogleIcon) ...[_GoogleIcon(), const SizedBox(width: 10)],
                      Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 22),
    );
  }
}
