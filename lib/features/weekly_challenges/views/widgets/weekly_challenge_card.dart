import 'dart:async';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WeeklyChallengeCard extends StatefulWidget {
  const WeeklyChallengeCard({super.key, this.cubit, this.now});
  final WeeklyChallengesCubit? cubit;
  final DateTime Function()? now;
  @override
  State<WeeklyChallengeCard> createState() => _WeeklyChallengeCardState();
}

class _WeeklyChallengeCardState extends State<WeeklyChallengeCard> with WidgetsBindingObserver {
  late final WeeklyChallengesCubit _cubit = widget.cubit ?? getIt<WeeklyChallengesCubit>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() => _cubit.loadOpen(clock: widget.now);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.cubit == null) unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<WeeklyChallengesCubit, WeeklyChallengesState>(
    bloc: _cubit,
    builder: (context, state) {
      final challenge = state.current;
      if (challenge == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          child: ListTile(
            title: Text(context.l10n.challengeTitle, style: PrismTextStyles.rowTitle(context)),
            subtitle: Text(challenge.theme),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.router.push(WeeklyChallengeRoute(challengeId: challenge.id)),
          ),
        ),
      );
    },
  );
}
