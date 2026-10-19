import 'package:Prism/core/debug/debug_flags.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/widgets/debug_widgets.dart';
import 'package:Prism/l10n/l10n.dart';
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
      showDebugSnackBar(context, context.l10n.debugCacheCleared);
    } catch (e) {
      if (!context.mounted) return;
      showDebugSnackBar(context, context.l10n.debugCouldNotClearCache(e.toString()), isError: true);
    }
  }

  Future<void> _forceCrash(BuildContext context) async {
    final bool ok = await showPrismConfirm(
      context,
      title: context.l10n.debugForceCrashTitle,
      message: context.l10n.debugForceCrashBody,
      confirmLabel: context.l10n.debugCrashApp,
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
          _Section(context.l10n.debugRendering),
          PrismGroup(
            children: [
              PrismSwitchRow(
                icon: Icons.grid_on_rounded,
                title: context.l10n.debugPaintSize,
                subtitle: context.l10n.debugPaintSizeDescription,
                value: DebugFlags.instance.paintSizeEnabled,
                onChanged: (v) => DebugFlags.instance.paintSizeEnabled = v,
              ),
              PrismSwitchRow(
                icon: Icons.color_lens_outlined,
                title: context.l10n.debugRepaintRainbow,
                subtitle: context.l10n.debugRepaintRainbowDescription,
                value: DebugFlags.instance.repaintRainbow,
                onChanged: (v) => DebugFlags.instance.repaintRainbow = v,
              ),
              PrismSwitchRow(
                icon: Icons.text_fields_rounded,
                title: context.l10n.debugPaintBaselines,
                subtitle: context.l10n.debugPaintBaselinesDescription,
                value: DebugFlags.instance.paintBaselines,
                onChanged: (v) => DebugFlags.instance.paintBaselines = v,
              ),
              PrismSwitchRow(
                icon: Icons.speed_rounded,
                title: context.l10n.debugPerformanceOverlay,
                subtitle: context.l10n.debugPerformanceOverlayDescription,
                value: DebugFlags.instance.showPerformanceOverlay,
                onChanged: (v) => DebugFlags.instance.showPerformanceOverlay = v,
              ),
              PrismSwitchRow(
                icon: Icons.accessibility_new_rounded,
                title: context.l10n.debugSemanticsDebugger,
                subtitle: context.l10n.debugSemanticsDebuggerDescription,
                value: DebugFlags.instance.showSemanticsDebugger,
                onChanged: (v) => DebugFlags.instance.showSemanticsDebugger = v,
              ),
            ],
          ),
          if (!kReleaseMode)
            Padding(
              padding: const EdgeInsets.only(top: PrismSpace.xs, left: PrismSpace.xxs),
              child: Text(context.l10n.debugPaintSizeWarning, style: PrismTextStyles.caption(context)),
            ),
          _Section(context.l10n.debugAnimationSpeed),
          const _AnimationSpeedCard(),
          _Section(context.l10n.debugLoggingAndNetwork),
          PrismGroup(
            children: [
              PrismSwitchRow(
                icon: Icons.notifications_active_outlined,
                title: context.l10n.debugShowLogToasts,
                subtitle: context.l10n.debugShowLogToastsDescription,
                value: DebugFlags.instance.showLogToasts,
                onChanged: (v) => DebugFlags.instance.showLogToasts = v,
              ),
              PrismSwitchRow(
                icon: Icons.wifi_off_rounded,
                title: context.l10n.debugSimulateNoInternet,
                subtitle: context.l10n.debugSimulateNoInternetDescription,
                value: DebugFlags.instance.simulateNoInternet,
                onChanged: (v) => DebugFlags.instance.simulateNoInternet = v,
              ),
            ],
          ),
          _Section(context.l10n.debugMaintenance),
          PrismGroup(
            children: [
              PrismRow(
                icon: Icons.image_not_supported_outlined,
                title: context.l10n.debugClearImageCache,
                subtitle: context.l10n.debugClearImageCacheDescription,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  showDebugSnackBar(context, context.l10n.debugImageCacheCleared);
                },
              ),
              PrismRow(
                icon: Icons.delete_sweep_outlined,
                title: context.l10n.debugClearAppCache,
                subtitle: context.l10n.debugClearAppCacheDescription,
                onTap: () => _clearAppCache(context),
              ),
              PrismRow(
                icon: Icons.restart_alt_rounded,
                title: context.l10n.debugResetFlags,
                subtitle: context.l10n.debugResetFlagsDescription,
                onTap: () {
                  DebugFlags.instance.reset();
                  showDebugSnackBar(context, context.l10n.debugFlagsReset);
                },
              ),
            ],
          ),
          _Section(context.l10n.debugAdminShortcuts),
          PrismGroup(
            children: [
              PrismRow(
                icon: Icons.analytics_outlined,
                title: context.l10n.adminFirestoreTelemetry,
                subtitle: context.l10n.debugFirestoreTelemetryDescription,
                onTap: () => context.router.push(const FirestoreTelemetryRoute()),
              ),
              PrismRow(
                icon: Icons.admin_panel_settings_outlined,
                title: context.l10n.adminTitle,
                subtitle: context.l10n.debugAdminReviewDescription,
                onTap: () => context.router.push(AdminReviewRoute()),
              ),
            ],
          ),
          _Section(context.l10n.debugDangerZone),
          PrismGroup(
            children: [
              PrismRow(
                icon: Icons.warning_amber_rounded,
                title: context.l10n.debugForceCrash,
                subtitle: context.l10n.debugForceCrashDescription,
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
              Expanded(child: Text(context.l10n.debugSpeed, style: PrismTextStyles.rowTitle(context))),
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
