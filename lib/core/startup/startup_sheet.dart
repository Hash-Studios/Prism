import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Tracks whether this session already showed a sheet that Prism opened on its own, such as the notification
/// pre-prompt or the session ended sheet. A feature that wants to open one checks [shown] first, so a user never gets
/// two in a row.
// ignore: avoid_classes_with_only_static_members
abstract final class StartupModalSlot {
  static final ValueNotifier<bool> shown = ValueNotifier<bool>(false);

  /// Takes the slot. Returns false when another startup sheet already has it.
  static bool tryClaim() {
    if (shown.value) return false;
    shown.value = true;
    return true;
  }

  @visibleForTesting
  static void reset() => shown.value = false;
}

/// A one-line question in a bottom sheet. Resolves to true only when the user taps [confirmLabel].
Future<bool> showStartupChoiceSheet(
  BuildContext context, {
  required String message,
  required String confirmLabel,
  required String dismissLabel,
}) async {
  final bool? confirmed = await showPrismSheet<bool>(
    context,
    builder: (BuildContext sheetContext) => PrismSheetBody(
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: PrismButton(
                label: dismissLabel,
                variant: PrismButtonVariant.ghost,
                maxLines: 2,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ),
            const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: PrismButton(
                label: confirmLabel,
                maxLines: 2,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ),
          ],
        ),
      ],
      child: Text(message, style: PrismTextStyles.cardTitle(sheetContext)),
    ),
  );
  return confirmed ?? false;
}
