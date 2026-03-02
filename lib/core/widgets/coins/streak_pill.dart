import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/material.dart';

class StreakPill extends StatelessWidget {
  const StreakPill({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!app_state.prismUser.loggedIn) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<StreakStatus>(
      valueListenable: CoinsService.instance.streakNotifier,
      builder: (context, status, _) {
        final int streakDay = status.streakDay.clamp(0, 7);
        final bool active = status.active;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 8),
          decoration: BoxDecoration(
            color: active ? Colors.orange.withValues(alpha: 0.18) : Theme.of(context).hintColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? Colors.orangeAccent : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.local_fire_department_rounded, size: compact ? 14 : 16, color: Colors.orangeAccent),
              SizedBox(width: compact ? 4 : 6),
              Text(
                '$streakDay',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
