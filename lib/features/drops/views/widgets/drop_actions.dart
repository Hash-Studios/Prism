import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/unlock_sheet.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the unlock sheet for a locked [wall] and sends the choice to the bloc.
void askToUnlock(BuildContext context, DropsState state, DropWall wall) {
  final DropEntity? drop = state.drop;
  if (drop == null) return;
  PrismHaptics.tap();
  final DropsBloc bloc = context.read<DropsBloc>();
  unawaited(
    showDropUnlockSheet(
      context,
      drop: drop,
      wall: wall,
      remaining: state.lockedWalls.length,
      onUnlock: (wallId) => bloc.add(DropsEvent.unlockRequested(wallId: wallId)),
      onWatch: () => CoinGate.forContext(
        context,
      ).watchAdForCoins(sourceTag: 'drops.unlock.ad', upsellSource: 'drops_unlock', isMounted: () => context.mounted),
    ),
  );
}

void toastUnlockResult(DropUnlockResult result) {
  switch (result.outcome) {
    case DropUnlockOutcome.unlocked:
      toasts.success(result.unlocked.length == 1 ? 'Wall unlocked' : '${result.unlocked.length} walls unlocked');
    case DropUnlockOutcome.alreadyUnlocked:
      toasts.info('You already have this one.');
    case DropUnlockOutcome.notLive:
      toasts.error('This Drop is over.');
    case DropUnlockOutcome.insufficient:
      toasts.error('Not enough coins.');
    case DropUnlockOutcome.failed:
      toasts.error("Couldn't unlock this. Try again.");
  }
}
