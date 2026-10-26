import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/biz/coin_gate.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/unlock_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the unlock sheet for a locked [wall], or for every wall left when [wall] is null, and sends the choice to the
/// bloc.
void askToUnlock(BuildContext context, DropsState state, DropWall? wall) {
  final DropEntity? drop = state.drop;
  if (drop == null) return;
  PrismHaptics.tap();
  final DropsBloc bloc = context.read<DropsBloc>();
  unawaited(
    showDropUnlockSheet(
      context,
      drop: drop,
      wall: wall,
      locked: state.lockedWalls,
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

/// Admins only: asks for a new name for [drop] and sends it to the bloc.
Future<void> askToRenameDrop(BuildContext context, DropEntity drop) async {
  final DropsBloc bloc = context.read<DropsBloc>();
  final TextEditingController name = TextEditingController(text: drop.displayTitle(context.l10n));
  final String? title = await showPrismSheet<String>(
    context,
    builder: (sheetContext) => PrismSheetBody(
      title: sheetContext.l10n.economyDropRename,
      actions: <Widget>[
        PrismButton(
          label: sheetContext.l10n.actionDone,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(name.text.trim()),
        ),
      ],
      child: PrismTextField(
        controller: name,
        hint: sheetContext.l10n.economyDropRenameHint,
        maxLength: 40,
        autofocus: true,
      ),
    ),
  );
  name.dispose();
  if (title == null || title.isEmpty) return;
  bloc.add(DropsEvent.renameRequested(title: title));
}

void toastRenameResult(BuildContext context, DropRenameResult result) {
  if (result.ok) {
    toasts.success(context.l10n.economyDropRenamed);
  } else {
    toasts.error(context.l10n.economyDropRenameFailed);
  }
}
