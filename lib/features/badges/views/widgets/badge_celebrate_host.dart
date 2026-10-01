import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/badges/domain/repositories/badge_repository.dart';
import 'package:Prism/features/badges/views/widgets/badge_celebrate_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shows the celebrate sheet for each new badge, one at a time, while this route is on top.
class BadgeCelebrateHost extends StatefulWidget {
  const BadgeCelebrateHost({super.key, required this.child, required this.onSeeRewards});

  final Widget child;
  final VoidCallback onSeeRewards;

  @override
  State<BadgeCelebrateHost> createState() => _BadgeCelebrateHostState();
}

class _BadgeCelebrateHostState extends State<BadgeCelebrateHost> with WidgetsBindingObserver {
  late final BadgeRepository _repository = getIt<BadgeRepository>();
  bool _scheduled = false;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository.unseen.addListener(_schedule);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ModalRoute.of(context);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repository.unseen.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || _showing || _repository.unseen.value.isEmpty || !mounted) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _tryShow();
    });
  }

  Future<void> _tryShow() async {
    if (_showing || _repository.unseen.value.isEmpty) return;
    final bool current = ModalRoute.of(context)?.isCurrent ?? true;
    final bool resumed =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    if (!current || !resumed) {
      return;
    }
    final EarnedBadge badge = _repository.unseen.value.first;
    _repository.markSeen(badge.id);
    _showing = true;
    await showBadgeCelebrateSheet(context, badge, onSeeRewards: widget.onSeeRewards);
    _showing = false;
    if (mounted) _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
