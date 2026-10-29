import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/updates/ota_update_controller.dart';
import 'package:Prism/core/updates/store_update_policy.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Lives on the dashboard, so nothing here runs before startup and onboarding finish. It checks for patches on
/// mount and on resume. It shows the restart message and the store-update sheet only while this route is on top,
/// the app is in front, and no paywall is open.
class AppUpdateHost extends StatefulWidget {
  const AppUpdateHost({
    super.key,
    required this.controller,
    required this.storeUpdate,
    required this.child,
    this.paywallPresenting,
  });

  final OtaUpdateController controller;

  /// Read when the host tries to show a prompt, after startup config has loaded.
  final StoreUpdate Function() storeUpdate;
  final ValueListenable<bool>? paywallPresenting;
  final Widget child;

  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost> with WidgetsBindingObserver {
  late final ValueListenable<bool> _paywall = widget.paywallPresenting ?? PaywallOrchestrator.instance.presenting;
  TabsRouter? _tabsRouter;
  bool _scheduled = false;
  bool _showing = false;
  bool _storeUpdateHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.announcement.addListener(_schedule);
    _paywall.addListener(_schedule);
    unawaited(widget.controller.check(trigger: 'launch'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ModalRoute.of(context);
    final TabsRouter? tabsRouter = TabsRouterScope.of(context, watch: true)?.controller;
    if (!identical(tabsRouter, _tabsRouter)) {
      _tabsRouter?.removeListener(_schedule);
      _tabsRouter = tabsRouter;
      _tabsRouter?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(widget.controller.check(trigger: 'resume'));
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.announcement.removeListener(_schedule);
    _paywall.removeListener(_schedule);
    _tabsRouter?.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || _showing || !mounted) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_tryShow());
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool get _canShow {
    final bool current = ModalRoute.of(context)?.isCurrent ?? true;
    final bool resumed =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    final bool activeTabRouteCovered = _tabsRouter?.activeRouterCanPop() ?? false;
    return current && resumed && !activeTabRouteCovered && !_paywall.value;
  }

  Future<void> _tryShow() async {
    if (_showing || !_canShow) return;
    if (!_storeUpdateHandled && widget.storeUpdate() == StoreUpdate.suggested) {
      _storeUpdateHandled = true;
      if (StartupModalSlot.tryClaim()) {
        _showing = true;
        final bool update = await showStartupChoiceSheet(
          context,
          message: context.l10n.updatesStoreUpdateAvailable,
          confirmLabel: context.l10n.wallpaperUpdatePrism,
          dismissLabel: context.l10n.coreNotNow,
        );
        _showing = false;
        if (update && mounted) {
          unawaited(openPrismLink(context, defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl));
        }
        if (mounted) _schedule();
        return;
      }
    }
    final PendingRestart? restart = widget.controller.announcement.value;
    if (restart == null) return;
    _showing = true;
    toasts.info(context.l10n.updatesRestartToFinish);
    try {
      await widget.controller.markAnnounced(restart);
    } finally {
      _showing = false;
      final PendingRestart? latest = widget.controller.announcement.value;
      if (mounted && latest != null && latest != restart) _schedule();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
