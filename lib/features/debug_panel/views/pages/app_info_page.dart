import 'dart:io';

import 'package:Prism/core/constants/admin_users.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/env/env.dart';
import 'package:Prism/features/debug_panel/views/widgets/debug_widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() => _loading = true);
    try {
      final devicePlugin = DeviceInfoPlugin();
      final pkgInfo = await PackageInfo.fromPlatform();

      if (Platform.isAndroid) {
        final info = await devicePlugin.androidInfo;
        _deviceInfo = {
          'Platform': 'Android',
          'Model': info.model,
          'Manufacturer': info.manufacturer,
          'Android Version': info.version.release,
          'SDK Int': info.version.sdkInt.toString(),
          'Device': info.device,
          'Brand': info.brand,
          'Hardware': info.hardware,
          'Board': info.board,
          'Fingerprint': info.fingerprint,
        };
      } else if (Platform.isIOS) {
        final info = await devicePlugin.iosInfo;
        _deviceInfo = {
          'Platform': 'iOS',
          'Model': info.model,
          'Name': info.name,
          'System Name': info.systemName,
          'System Version': info.systemVersion,
          'Identifier': info.identifierForVendor ?? 'N/A',
          'Is Physical Device': info.isPhysicalDevice.toString(),
        };
      }

      _packageInfo = {
        'App Name': pkgInfo.appName,
        'Package Name': pkgInfo.packageName,
        'Version': pkgInfo.version,
        'Build Number': pkgInfo.buildNumber,
        'Build Signature': pkgInfo.buildSignature.isEmpty ? 'N/A' : pkgInfo.buildSignature,
      };

      try {
        final rc = getIt<FirebaseRemoteConfig>();
        _remoteConfig = {};
        for (final key in rc.getAll().keys) {
          _remoteConfig[key] = rc.getString(key);
        }
      } catch (_) {
        _remoteConfig = {'error': 'Remote Config unavailable'};
      }
    } catch (e) {
      _deviceInfo = {'error': e.toString()};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, String> get _userInfo {
    final u = app_state.prismUser;
    return {
      'Email': u.email.isEmpty ? 'Not signed in' : u.email,
      'User ID': u.id.isEmpty ? 'N/A' : u.id,
      'Username': u.username.isEmpty ? 'N/A' : u.username,
      'Is Admin': isAdminEmail(u.email).toString(),
      'Is Premium': u.premium.toString(),
      'Subscription Tier': u.subscriptionTier,
      'Coins': u.coins.toString(),
      'Logged In': u.loggedIn.toString(),
    };
  }

  Map<String, String> get _envInfo {
    return {
      'App Version': '${app_state.currentAppVersion}+${app_state.currentAppVersionCode}',
      'Persistence Backend': PersistenceRuntime.isInitialized
          ? PersistenceRuntime.store.runtimeType.toString()
          : 'unknown',
      'Sentry DSN Present': Env.sentryDsn.isNotEmpty.toString(),
      'Sentry Env': Env.sentryEnvironment.isEmpty ? '(default)' : Env.sentryEnvironment,
      'Sentry Enabled': Env.sentryEnabled,
      'Mixpanel Enabled': Env.mixpanelEnabled,
      'Mixpanel Token Present': Env.mixpanelToken.isNotEmpty.toString(),
      'RC API Key Present': Env.rcApiKey.isNotEmpty.toString(),
      'Pexels Key Present': Env.pexelsApiKey.isNotEmpty.toString(),
    };
  }

  Map<String, String> get _screenInfo {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize;
    final dpr = view.devicePixelRatio;
    return {
      'Physical Size': '${size.width.toInt()} × ${size.height.toInt()} px',
      'Logical Size': '${(size.width / dpr).toStringAsFixed(0)} × ${(size.height / dpr).toStringAsFixed(0)} dp',
      'Device Pixel Ratio': dpr.toStringAsFixed(2),
    };
  }

  String _buildDiagnosticReport() {
    final buf = StringBuffer();
    buf.writeln('=== Prism Debug Diagnostic Report ===');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln();

    void section(String title, Map<String, String> data) {
      buf.writeln('--- $title ---');
      for (final e in data.entries) {
        buf.writeln('${e.key}: ${e.value}');
      }
      buf.writeln();
    }

    section('Package', _packageInfo);
    section('Environment', _envInfo);
    section('User', _userInfo);
    section('Device', _deviceInfo);
    section('Screen', _screenInfo);
    if (_remoteConfig.isNotEmpty) section('Remote Config', _remoteConfig);

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text('Copy Full Diagnostic Report'),
            onPressed: () => copyToClipboard(
              context,
              _buildDiagnosticReport(),
              label: 'Diagnostic report copied to clipboard',
              duration: const Duration(seconds: 2),
            ),
          ),
        ),
        _InfoSection(title: 'Package', data: _packageInfo),
        _InfoSection(title: 'Environment', data: _envInfo),
        _InfoSection(title: 'User', data: _userInfo),
        _InfoSection(title: 'Device', data: _deviceInfo),
        _InfoSection(title: 'Screen', data: _screenInfo),
        if (_remoteConfig.isNotEmpty) _InfoSection(title: 'Remote Config', data: _remoteConfig),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            onPressed: _loadInfo,
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.data});
  final String title;
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DebugSectionHeader(title, top: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              for (final (i, e) in data.entries.indexed)
                Container(
                  decoration: BoxDecoration(
                    border: i == data.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
                  ),
                  child: _InfoRow(label: e.key, value: e.value),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      enableFeedback: false,
      onLongPress: () {
        PrismHaptics.impact();
        copyToClipboard(context, value, label: 'Copied: $value');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7)),
              ),
            ),
            Expanded(
              child: SelectableText(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }
}
