import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/unlock_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
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

void toastUnlockResult(BuildContext context, DropUnlockResult result) {
  final AppLocalizations l10n = context.l10n;
  switch (result.outcome) {
    case DropUnlockOutcome.unlocked:
      toasts.success(l10n.economyDropUnlockedCountToast(result.unlocked.length));
    case DropUnlockOutcome.alreadyUnlocked:
      toasts.info(l10n.economyDropAlreadyUnlocked);
    case DropUnlockOutcome.notLive:
      toasts.error(l10n.economyDropOver);
    case DropUnlockOutcome.insufficient:
      toasts.error(l10n.economyNotEnoughCoins);
    case DropUnlockOutcome.failed:
      toasts.error(l10n.economyDropUnlockFailed);
  }
}
