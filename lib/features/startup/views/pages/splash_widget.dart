import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:Prism/features/startup/views/pages/old_version_screen.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the user should land on onboarding instead of the dashboard.
///
/// A guest (never signed in, but already onboarded) only counts as "signed
/// in enough" to skip onboarding where guest browsing is allowed (iOS).
/// Logout and account deletion reset [isOnboarded] to false, so a guest who
/// signs out sees onboarding again. Extracted as a pure function so the
/// routing decision is unit-testable without a widget tree.
bool shouldShowOnboarding({
  required bool isLoggedIn,
  required bool isOnboarded,
  required bool v2Enabled,
  required bool guestBrowsingAllowed,
}) {
  final bool treatAsSignedIn = isLoggedIn || (guestBrowsingAllowed && isOnboarded);
  return !treatAsSignedIn || (!isOnboarded && v2Enabled);
}

@RoutePage(name: 'SplashWidgetRoute')
class SplashWidget extends StatefulWidget {
  const SplashWidget({super.key});

  @override
  State<SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool _navigated = false;

  // Tracks whether the debug-forced onboarding redirect has already fired this
  // app session. Resets on process restart (static lives for the process lifetime).
  static bool _debugOnboardingShownThisSession = false;

  @override
  void initState() {
    super.initState();
    // If startup already succeeded (e.g. returning from onboarding), the
    // BlocConsumer listener won't fire because there's no state change.
    // Schedule an immediate check so navigation still happens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<StartupBloc>().state;
      if (s.status == LoadStatus.success && !s.isObsoleteVersion) {
        _navigatePostBootstrap(context);
      }
    });
  }

  void _navigatePostBootstrap(BuildContext context) {
    if (_navigated) {
      return;
    }
    _navigated = true;
    final effectiveDebugForce = OnboardingV2Config.debugForceOnboarding && !_debugOnboardingShownThisSession;
    final isOnboarded =
        !effectiveDebugForce && _settingsLocal.get<bool>(OnboardingV2Keys.onboardedNew, defaultValue: false);
    final v2Enabled = effectiveDebugForce || (context.read<StartupBloc>().state.config?.onboardingV2Enabled ?? false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final bool showOnboarding = shouldShowOnboarding(
        isLoggedIn: app_state.prismUser.loggedIn,
        isOnboarded: isOnboarded,
        v2Enabled: v2Enabled,
        // Guest browsing (no account) only exists on iOS; Android always forces sign-in.
        guestBrowsingAllowed: defaultTargetPlatform == TargetPlatform.iOS,
      );
      if (showOnboarding) {
        _debugOnboardingShownThisSession = true;
        context.router.replaceAll([const OnboardingV2ShellRoute()]);
      } else {
        context.router.replaceAll([const DashboardRoute()]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StartupBloc, StartupState>(
      listener: (context, state) {
        if (state.status == LoadStatus.success && !state.isObsoleteVersion) {
          _navigatePostBootstrap(context);
        }
      },
      builder: (context, state) {
        final Widget content;
        if (state.status == LoadStatus.success && state.isObsoleteVersion) {
          content = const KeyedSubtree(key: ValueKey<String>('old'), child: OldVersion());
        } else if (state.status == LoadStatus.failure) {
          content = _StartupFailure(
            key: const ValueKey<String>('failure'),
            onRetry: () =>
                context.read<StartupBloc>().add(StartupEvent.started(currentVersion: app_state.currentAppVersion)),
          );
        } else {
          content = const _SecondarySplash(key: ValueKey<String>('splash'));
        }
        return AnimatedSwitcher(
          duration: context.motion(PrismDurations.slow),
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.exit,
          child: content,
        );
      },
    );
  }
}

class _SecondarySplash extends StatelessWidget {
  const _SecondarySplash({super.key});

  @override
  Widget build(BuildContext context) {
    final double size = MediaQuery.sizeOf(context).width * 0.29074074074;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Semantics(
          label: 'Prism',
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.225),
            child: Image.asset('assets/images/ic_launcher.webp', width: size, height: size, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: GlintState(
          kind: GlintStateKind.error,
          title: 'Prism could not start',
          body: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: onRetry,
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xxl, vertical: PrismSpace.xl),
        ),
      ),
    );
  }
}
