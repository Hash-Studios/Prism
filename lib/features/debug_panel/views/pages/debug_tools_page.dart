import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DebugToolsPage extends StatefulWidget {
  const DebugToolsPage({super.key});

  @override
  State<DebugToolsPage> createState() => _DebugToolsPageState();
}

class _DebugToolsPageState extends State<DebugToolsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: DebugFlags.instance,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionHeader('Rendering (Debug/Profile only)'),
          _ToggleTile(
            icon: Icons.grid_on,
            title: 'Paint Size Enabled',
            subtitle: 'Show layout bounds on all widgets',
            value: DebugFlags.instance.paintSizeEnabled,
            onChanged: (v) => DebugFlags.instance.paintSizeEnabled = v,
          ),
          _ToggleTile(
            icon: Icons.color_lens_outlined,
            title: 'Repaint Rainbow',
            subtitle: 'Highlight repainted areas in rotating colors',
            value: DebugFlags.instance.repaintRainbow,
            onChanged: (v) => DebugFlags.instance.repaintRainbow = v,
          ),
          _ToggleTile(
            icon: Icons.text_fields,
            title: 'Paint Baselines',
            subtitle: 'Show text baseline guides',
            value: DebugFlags.instance.paintBaselines,
            onChanged: (v) => DebugFlags.instance.paintBaselines = v,
          ),
          _ToggleTile(
            icon: Icons.speed,
            title: 'Performance Overlay',
            subtitle: 'GPU and CPU usage graphs',
            value: DebugFlags.instance.showPerformanceOverlay,
            onChanged: (v) => DebugFlags.instance.showPerformanceOverlay = v,
          ),
          _ToggleTile(
            icon: Icons.accessibility_new,
            title: 'Semantics Debugger',
            subtitle: 'Overlay accessibility tree labels',
            value: DebugFlags.instance.showSemanticsDebugger,
            onChanged: (v) => DebugFlags.instance.showSemanticsDebugger = v,
          ),
          _SectionHeader('Animation Speed'),
          _AnimationSpeedTile(),
          _SectionHeader('Logging'),
          _ToggleTile(
            icon: Icons.notifications_active_outlined,
            title: 'Show Log Toasts',
            subtitle: 'Display log entries as brief overlay toasts',
            value: DebugFlags.instance.showLogToasts,
            onChanged: (v) => DebugFlags.instance.showLogToasts = v,
          ),
          _SectionHeader('Network'),
          _ToggleTile(
            icon: Icons.wifi_off,
            title: 'Simulate No Internet',
            subtitle: 'Overrides connectivity checks to report offline',
            value: DebugFlags.instance.simulateNoInternet,
            onChanged: (v) => DebugFlags.instance.simulateNoInternet = v,
          ),
          _SectionHeader('Maintenance'),
          _ActionTile(
            icon: Icons.image_not_supported_outlined,
            title: 'Clear Image Cache',
            subtitle: 'Evict in-memory image cache',
            onTap: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Image cache cleared'), duration: Duration(seconds: 2)));
            },
          ),
          _ActionTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Clear App Cache',
            subtitle: 'Clear images, feed and notification cache',
            onTap: () async {
              try {
                await getIt<CacheMaintenanceService>().clearTransientCache();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('App cache cleared'), duration: Duration(seconds: 2)));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)));
              }
            },
          ),
          _ActionTile(
            icon: Icons.restore,
            title: 'Reset All Debug Flags',
            subtitle: 'Restore all toggles to default values',
            onTap: () {
              DebugFlags.instance.reset();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Debug flags reset'), duration: Duration(seconds: 2)));
            },
          ),
          _SectionHeader('Admin Shortcuts'),
          _ActionTile(
            icon: Icons.analytics_outlined,
            title: 'Firestore Telemetry',
            subtitle: 'View Firestore read/write profiling',
            onTap: () => context.router.pushPath('/admin-firestore-telemetry'),
          ),
          _ActionTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Admin Review',
            subtitle: 'Content moderation & push notification tool',
            onTap: () => context.router.pushPath('/admin-review'),
          ),
          _SectionHeader('Danger Zone'),
          _ActionTile(
            icon: Icons.warning_amber,
            title: 'Force Crash',
            subtitle: 'Throw an exception to test Sentry reporting',
            color: Colors.red,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Force Crash?'),
                  content: const Text('This will throw an exception to verify Sentry error reporting is working.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        throw StateError('[DebugPanel] Force crash triggered by admin for Sentry test.');
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Crash'),
                    ),
                  ],
                ),
              );
            },
          ),
          if (!kReleaseMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Rendering flags (paint size, repaint rainbow, baselines) only work in debug/profile builds.',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Theme.of(context).colorScheme.secondary,
      dense: true,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.secondary;
    return ListTile(
      leading: Icon(icon, size: 22, color: color),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
      dense: true,
      trailing: Icon(Icons.chevron_right, size: 16, color: effectiveColor.withValues(alpha: 0.5)),
    );
  }
}

class _AnimationSpeedTile extends StatelessWidget {
  const _AnimationSpeedTile();

  static const List<double> _presets = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    final speed = DebugFlags.instance.animationSpeed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.slow_motion_video, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Animation Speed: ${speed.toStringAsFixed(1)}×',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          Slider(
            value: speed,
            min: 0.1,
            max: 10.0,
            divisions: 99,
            label: '${speed.toStringAsFixed(1)}×',
            activeColor: Theme.of(context).colorScheme.secondary,
            onChanged: (v) => DebugFlags.instance.animationSpeed = v,
          ),
          Wrap(
            spacing: 6,
            children: _presets.map((p) {
              final isActive = (speed - p).abs() < 0.05;
              return ActionChip(
                label: Text('$p×', style: const TextStyle(fontSize: 11)),
                backgroundColor: isActive ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2) : null,
                side: isActive ? BorderSide(color: Theme.of(context).colorScheme.secondary) : null,
                onPressed: () => DebugFlags.instance.animationSpeed = p,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
