import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/widgets/debug_widgets.dart';
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

  Future<void> _clearAppCache(BuildContext context) async {
    try {
      await getIt<CacheMaintenanceService>().clearTransientCache();
      if (!context.mounted) return;
      showDebugSnackBar(context, 'App cache cleared');
    } catch (e) {
      if (!context.mounted) return;
      showDebugSnackBar(context, 'Could not clear the app cache: $e', isError: true);
    }
  }

  Future<void> _forceCrash(BuildContext context) async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Force crash?',
      message: 'This throws an exception to check that Sentry reports errors.',
      confirmLabel: 'Crash the app',
      destructive: true,
    );
    if (ok) throw StateError('[DebugPanel] Force crash triggered by admin for Sentry test.');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: DebugFlags.instance,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xxl),
        children: [
          const _Section('Rendering'),
          PrismGroup(
            children: [
              PrismSwitchRow(
                icon: Icons.grid_on_rounded,
                title: 'Paint size',
                subtitle: 'Show layout bounds on all widgets',
                value: DebugFlags.instance.paintSizeEnabled,
                onChanged: (v) => DebugFlags.instance.paintSizeEnabled = v,
              ),
              PrismSwitchRow(
                icon: Icons.color_lens_outlined,
                title: 'Repaint rainbow',
                subtitle: 'Highlight repainted areas in rotating colors',
                value: DebugFlags.instance.repaintRainbow,
                onChanged: (v) => DebugFlags.instance.repaintRainbow = v,
              ),
              PrismSwitchRow(
                icon: Icons.text_fields_rounded,
                title: 'Paint baselines',
                subtitle: 'Show text baseline guides',
                value: DebugFlags.instance.paintBaselines,
                onChanged: (v) => DebugFlags.instance.paintBaselines = v,
              ),
              PrismSwitchRow(
                icon: Icons.speed_rounded,
                title: 'Performance overlay',
                subtitle: 'GPU and CPU usage graphs',
                value: DebugFlags.instance.showPerformanceOverlay,
                onChanged: (v) => DebugFlags.instance.showPerformanceOverlay = v,
              ),
              PrismSwitchRow(
                icon: Icons.accessibility_new_rounded,
                title: 'Semantics debugger',
                subtitle: 'Overlay accessibility tree labels',
                value: DebugFlags.instance.showSemanticsDebugger,
                onChanged: (v) => DebugFlags.instance.showSemanticsDebugger = v,
              ),
            ],
          ),
          if (!kReleaseMode)
            Padding(
              padding: const EdgeInsets.only(top: PrismSpace.xs, left: PrismSpace.xxs),
              child: Text(
                'Paint size, repaint rainbow and baselines only work in debug and profile builds.',
                style: PrismTextStyles.caption(context),
              ),
            ),
          const _Section('Animation speed'),
          const _AnimationSpeedCard(),
          const _Section('Logging and network'),
          PrismGroup(
            children: [
              PrismSwitchRow(
                icon: Icons.notifications_active_outlined,
                title: 'Show log toasts',
                subtitle: 'Display log entries as brief overlay toasts',
                value: DebugFlags.instance.showLogToasts,
                onChanged: (v) => DebugFlags.instance.showLogToasts = v,
              ),
              PrismSwitchRow(
                icon: Icons.wifi_off_rounded,
                title: 'Simulate no internet',
                subtitle: 'Overrides connectivity checks to report offline',
                value: DebugFlags.instance.simulateNoInternet,
                onChanged: (v) => DebugFlags.instance.simulateNoInternet = v,
              ),
            ],
          ),
          const _Section('Maintenance'),
          PrismGroup(
            children: [
              PrismRow(
                icon: Icons.image_not_supported_outlined,
                title: 'Clear image cache',
                subtitle: 'Evict in-memory image cache',
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  showDebugSnackBar(context, 'Image cache cleared');
                },
              ),
              PrismRow(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear app cache',
                subtitle: 'Clear images, feed and notification cache',
                onTap: () => _clearAppCache(context),
              ),
              PrismRow(
                icon: Icons.restart_alt_rounded,
                title: 'Reset all debug flags',
                subtitle: 'Restore all toggles to default values',
                onTap: () {
                  DebugFlags.instance.reset();
                  showDebugSnackBar(context, 'Debug flags reset');
                },
              ),
            ],
          ),
          const _Section('Admin shortcuts'),
          PrismGroup(
            children: [
              PrismRow(
                icon: Icons.analytics_outlined,
                title: 'Firestore telemetry',
                subtitle: 'View Firestore read and write profiling',
                onTap: () => context.router.push(const FirestoreTelemetryRoute()),
              ),
              PrismRow(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin review',
                subtitle: 'Content moderation and push notification tool',
                onTap: () => context.router.push(AdminReviewRoute()),
              ),
            ],
          ),
          const _Section('Danger zone'),
          PrismGroup(
            children: [
              PrismRow(
                icon: Icons.warning_amber_rounded,
                title: 'Force crash',
                subtitle: 'Throw an exception to test Sentry reporting',
                destructive: true,
                onTap: () => _forceCrash(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => PrismSectionHeader(
    title: title,
    small: true,
    padding: const EdgeInsets.only(top: PrismSpace.xl, bottom: PrismSpace.xs, left: PrismSpace.xxs),
  );
}

class _AnimationSpeedCard extends StatelessWidget {
  const _AnimationSpeedCard();

  static const List<double> _presets = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    final double speed = DebugFlags.instance.animationSpeed;
    return PrismCard(
      padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.sm, PrismSpace.md, PrismSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Speed', style: PrismTextStyles.rowTitle(context))),
              Text('${speed.toStringAsFixed(1)}×', style: PrismTextStyles.rowTitle(context)),
            ],
          ),
          Slider(
            value: speed,
            min: 0.1,
            max: 10.0,
            divisions: 99,
            label: '${speed.toStringAsFixed(1)}×',
            onChanged: (v) => DebugFlags.instance.animationSpeed = v,
          ),
          Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: [
              for (final double p in _presets)
                PrismChip(
                  label: '$p×',
                  selected: (speed - p).abs() < 0.05,
                  onTap: () => DebugFlags.instance.animationSpeed = p,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
