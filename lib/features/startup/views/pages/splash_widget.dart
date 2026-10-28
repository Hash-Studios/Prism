import 'dart:math' as math;

import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/version_compare.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:Prism/features/startup/views/pages/old_version_screen.dart';
import 'package:Prism/l10n/l10n.dart';
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
      final bool bootstrapDone = s.status == LoadStatus.success || s.status == LoadStatus.failure;
      if (bootstrapDone ? s.status == LoadStatus.success && !s.isObsoleteVersion : _canSkipBootstrap()) {
        _navigatePostBootstrap(context);
      }
    });
  }

  /// A returning user only waits on bootstrap to learn whether this version is obsolete. The last answer is stored, so
  /// route on it; [ObsoleteVersionGate] covers a version that turns obsolete later.
  bool _canSkipBootstrap() {
    final String lastObsolete = _settingsLocal.get<String>(PersistenceKeys.obsoleteAppVersion, defaultValue: '');
    if (lastObsolete.isEmpty || isVersionOlder(app_state.currentAppVersion, lastObsolete)) {
      return false;
    }
    final bool isOnboarded =
        !(OnboardingV2Config.debugForceOnboarding && !_debugOnboardingShownThisSession) &&
        _settingsLocal.get<bool>(OnboardingV2Keys.onboardedNew, defaultValue: false);
    return !<bool>[true, false].any(
      (v2) => shouldShowOnboarding(
        isLoggedIn: app_state.prismUser.loggedIn,
        isOnboarded: isOnboarded,
        v2Enabled: v2,
        guestBrowsingAllowed: true,
      ),
    );
  }

  void _navigatePostBootstrap(BuildContext context) {
    if (_navigated) {
      return;
    }
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final startup = context.read<StartupBloc>().state;
      if (startup.isObsoleteVersion) {
        _navigated = false;
        return;
      }
      final effectiveDebugForce = OnboardingV2Config.debugForceOnboarding && !_debugOnboardingShownThisSession;
      final isOnboarded =
          !effectiveDebugForce && _settingsLocal.get<bool>(OnboardingV2Keys.onboardedNew, defaultValue: false);
      final v2Enabled = effectiveDebugForce || (startup.config?.onboardingV2Enabled ?? false);
      final bool showOnboarding = shouldShowOnboarding(
        isLoggedIn: app_state.prismUser.loggedIn,
        isOnboarded: isOnboarded,
        v2Enabled: v2Enabled,
        guestBrowsingAllowed: true,
      );
      if (showOnboarding) {
        _debugOnboardingShownThisSession = true;
        if (!kReleaseMode) {
          PerformanceProbe.emit(
            kind: 'startup',
            name: 'time_to_onboarding',
            durationMs: PerformanceProbe.sinceProcess.elapsedMilliseconds,
          );
        }
        context.router.replaceAll([OnboardingV2ShellRoute()]);
      } else {
        if (!kReleaseMode) {
          PerformanceProbe.emit(
            kind: 'startup',
            name: 'time_to_home',
            durationMs: PerformanceProbe.sinceProcess.elapsedMilliseconds,
          );
        }
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
            onRetry: () => context.read<StartupBloc>().add(
              StartupEvent.started(
                currentVersion: app_state.currentAppVersion,
                currentBuild: app_state.currentAppVersionCode,
              ),
            ),
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
    final double size = math.min(MediaQuery.sizeOf(context).width * 0.29074074074, 140);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Semantics(
          label: context.l10n.wallpaperHomeAppName,
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
          title: context.l10n.wallpaperStartupFailed,
          body: context.l10n.wallpaperCheckConnection,
          actionLabel: context.l10n.wallpaperTryAgain,
          onAction: () {
            PrismHaptics.tap();
            onRetry();
          },
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xxl, vertical: PrismSpace.xl),
        ),
      ),
    );
  }
}
