import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:Prism/features/startup/views/pages/old_version_screen.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage(name: 'SplashWidgetRoute')
class SplashWidget extends StatefulWidget {
  const SplashWidget({super.key});

  @override
  State<SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool _navigated = false;
  bool _notchMeasured = false;

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

  void _measureNotch(BuildContext context) {
    if (_notchMeasured) {
      return;
    }
    final height = MediaQuery.of(context).padding.top;
    app_state.hasNotch = height > 24;
    app_state.notchSize = height;
    context.read<StartupBloc>().add(StartupEvent.notchMeasured(notchHeight: height));
    _notchMeasured = true;
    logger.d('Notch Height = $height');
  }

  void _navigatePostBootstrap(BuildContext context) {
    if (_navigated) {
      return;
    }
    _navigated = true;
    final isOnboarded = _settingsLocal.get<bool>('onboarded_v2_new', defaultValue: false);
    final v2Enabled = context.read<StartupBloc>().state.config?.onboardingV2Enabled ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!isOnboarded && v2Enabled) {
        context.router.replaceAll([const OnboardingV2ShellRoute()]);
      } else {
        context.router.replaceAll([const DashboardRoute()]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureNotch(context);

    return BlocConsumer<StartupBloc, StartupState>(
      listener: (context, state) {
        if (state.status == LoadStatus.success && !state.isObsoleteVersion) {
          _navigatePostBootstrap(context);
        }
      },
      builder: (context, state) {
        if (state.status == LoadStatus.success && state.isObsoleteVersion) {
          return OldVersion();
        }
        return const _SecondarySplash();
      },
    );
  }
}

class _SecondarySplash extends StatelessWidget {
  const _SecondarySplash();

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final bool darkModeOn = brightness == Brightness.dark;
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: darkModeOn ? config.Colors().mainDarkColor(1) : config.Colors().mainColor(1),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.29074074074,
          height: MediaQuery.of(context).size.width * 0.29074074074,
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage('assets/images/ic_launcher.webp'), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
