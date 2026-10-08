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
  String dismissLabel = 'Not now',
}) async {
  final bool? confirmed = await showPrismSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(message, style: PrismTextStyles.cardTitle(sheetContext)),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(onPressed: () => Navigator.of(sheetContext).pop(false), child: Text(dismissLabel)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: () => Navigator.of(sheetContext).pop(true), child: Text(confirmLabel)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}
