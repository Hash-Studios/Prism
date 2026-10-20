import 'dart:io';

import 'package:Prism/core/constants/admin_users.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/debug_panel/views/widgets/debug_widgets.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoPage extends StatefulWidget {
  const AppInfoPage({super.key});

  @override
  State<AppInfoPage> createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, String> _deviceInfo = {};
  Map<String, String> _packageInfo = {};
  Map<String, String> _remoteConfig = {};
  bool _loading = true;
  bool _hasLoadedInfo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedInfo) return;
    _hasLoadedInfo = true;
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _loading = true);
    try {
      final devicePlugin = DeviceInfoPlugin();
      final pkgInfo = await PackageInfo.fromPlatform();

      if (Platform.isAndroid) {
        final info = await devicePlugin.androidInfo;
        _deviceInfo = {
          l10n.debugPlatform: 'Android',
          l10n.debugModel: info.model,
          l10n.debugManufacturer: info.manufacturer,
          l10n.debugAndroidVersion: info.version.release,
          l10n.debugSdkInt: info.version.sdkInt.toString(),
          l10n.debugDeviceName: info.device,
          l10n.debugBrand: info.brand,
          l10n.debugHardware: info.hardware,
          l10n.debugBoard: info.board,
          l10n.debugFingerprint: info.fingerprint,
        };
      } else if (Platform.isIOS) {
        final info = await devicePlugin.iosInfo;
        _deviceInfo = {
          l10n.debugPlatform: 'iOS',
          l10n.debugModel: info.model,
          l10n.debugName: info.name,
          l10n.debugSystemName: info.systemName,
          l10n.debugSystemVersion: info.systemVersion,
          l10n.debugIdentifier: info.identifierForVendor ?? l10n.debugNotAvailable,
          l10n.debugPhysicalDevice: info.isPhysicalDevice.toString(),
        };
      }

      _packageInfo = {
        l10n.debugAppName: pkgInfo.appName,
        l10n.debugPackageName: pkgInfo.packageName,
        l10n.debugVersion: pkgInfo.version,
        l10n.debugBuildNumber: pkgInfo.buildNumber,
        l10n.debugBuildSignature: pkgInfo.buildSignature.isEmpty ? l10n.debugNotAvailable : pkgInfo.buildSignature,
      };

      try {
        final rc = getIt<FirebaseRemoteConfig>();
        _remoteConfig = {};
        for (final key in rc.getAll().keys) {
          _remoteConfig[key] = rc.getString(key);
        }
      } catch (_) {
        _remoteConfig = {l10n.debugErrorValue: l10n.debugRemoteConfigUnavailable};
      }
    } catch (e) {
      _deviceInfo = {l10n.debugErrorValue: e.toString()};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, String> get _userInfo {
    final u = app_state.prismUser;
    return {
      context.l10n.debugEmail: u.email.isEmpty ? context.l10n.debugNotSignedIn : u.email,
      context.l10n.debugUserId: u.id.isEmpty ? context.l10n.debugNotAvailable : u.id,
      context.l10n.debugUsername: u.username.isEmpty ? context.l10n.debugNotAvailable : u.username,
      context.l10n.debugIsAdmin: isAdminEmail(u.email).toString(),
      context.l10n.debugIsPremium: u.premium.toString(),
      context.l10n.debugSubscriptionTier: u.subscriptionTier,
      context.l10n.debugCoins: u.coins.toString(),
      context.l10n.debugLoggedIn: u.loggedIn.toString(),
    };
  }

  Map<String, String> get _envInfo {
    return {
      context.l10n.debugAppVersion: '${app_state.currentAppVersion}+${app_state.currentAppVersionCode}',
      context.l10n.debugPersistenceBackend: PersistenceRuntime.isInitialized
          ? PersistenceRuntime.store.runtimeType.toString()
          : 'unknown',
      context.l10n.debugSentryDsnPresent: Env.sentryDsn.isNotEmpty.toString(),
      context.l10n.debugSentryEnv: Env.sentryEnvironment.isEmpty
          ? context.l10n.debugDefaultValue
          : Env.sentryEnvironment,
      context.l10n.debugSentryEnabled: Env.sentryEnabled,
      context.l10n.debugMixpanelEnabled: Env.mixpanelEnabled,
      context.l10n.debugMixpanelTokenPresent: Env.mixpanelToken.isNotEmpty.toString(),
      context.l10n.debugRcApiKeyPresent: Env.rcApiKey.isNotEmpty.toString(),
      context.l10n.debugPexelsKeyPresent: Env.pexelsApiKey.isNotEmpty.toString(),
    };
  }

  Map<String, String> get _screenInfo {
    final view = View.of(context);
    final size = view.physicalSize;
    final dpr = view.devicePixelRatio;
    return {
      context.l10n.debugPhysicalSize: '${size.width.toInt()} × ${size.height.toInt()} px',
      context.l10n.debugLogicalSize:
          '${(size.width / dpr).toStringAsFixed(0)} × ${(size.height / dpr).toStringAsFixed(0)} dp',
      context.l10n.debugDevicePixelRatio: NumberFormat('0.00', context.l10n.localeName).format(dpr),
    };
  }

  String _buildDiagnosticReport() {
    final buf = StringBuffer();
    buf.writeln(context.l10n.debugDiagnosticReportHeading);
    buf.writeln(context.l10n.debugGeneratedAt(DateTime.now().toIso8601String()));
    buf.writeln();

    void section(String title, Map<String, String> data) {
      buf.writeln('--- $title ---');
      for (final e in data.entries) {
        buf.writeln('${e.key}: ${e.value}');
      }
      buf.writeln();
    }

    section(context.l10n.debugPackage, _packageInfo);
    section(context.l10n.debugEnvironment, _envInfo);
    section(context.l10n.debugUser, _userInfo);
    section(context.l10n.debugDevice, _deviceInfo);
    section(context.l10n.debugScreen, _screenInfo);
    if (_remoteConfig.isNotEmpty) section(context.l10n.debugRemoteConfig, _remoteConfig);

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return PrismSkeleton.rows(avatar: false, rows: 10);

    return ListView(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.xxl),
      children: [
        Row(
          children: [
            Expanded(
              child: PrismButton(
                label: context.l10n.debugCopyDiagnosticReport,
                icon: Icons.copy_all_rounded,
                variant: PrismButtonVariant.tonal,
                onPressed: () =>
                    copyToClipboard(context, _buildDiagnosticReport(), label: context.l10n.debugDiagnosticCopied),
              ),
            ),
            const SizedBox(width: PrismSpace.xs),
            PrismIconButton(
              icon: Icons.refresh_rounded,
              tooltip: context.l10n.debugRefresh,
              filled: true,
              onPressed: _loadInfo,
            ),
          ],
        ),
        _InfoSection(title: context.l10n.debugPackage, data: _packageInfo),
        _InfoSection(title: context.l10n.debugEnvironment, data: _envInfo),
        _InfoSection(title: context.l10n.debugUser, data: _userInfo),
        _InfoSection(title: context.l10n.debugDevice, data: _deviceInfo),
        _InfoSection(title: context.l10n.debugScreen, data: _screenInfo),
        if (_remoteConfig.isNotEmpty) _InfoSection(title: context.l10n.debugRemoteConfig, data: _remoteConfig),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.data});
  final String title;
  final Map<String, String> data;

  /// Values up to this length sit beside the label. Longer ones go under it so they can wrap.
  static const int _inlineMax = 18;

  @override
  Widget build(BuildContext context) {
    final Color hint = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSectionHeader(
          title: title,
          small: true,
          padding: const EdgeInsets.only(top: PrismSpace.xl, bottom: PrismSpace.xs, left: PrismSpace.xxs),
        ),
        PrismGroup(
          children: [
            for (final e in data.entries)
              PrismRow(
                title: e.key,
                value: e.value.length <= _inlineMax ? e.value : null,
                subtitle: e.value.length <= _inlineMax ? null : e.value,
                trailing: Icon(Icons.copy_rounded, size: 16, color: hint),
                onTap: () {
                  PrismHaptics.impact();
                  copyToClipboard(context, e.value);
                },
              ),
          ],
        ),
      ],
    );
  }
}
