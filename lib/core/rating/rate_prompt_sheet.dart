import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

enum RatePromptChoice { yes, notReally, dismissed }

/// The first step of the rate prompt. Closing the sheet any other way counts as [RatePromptChoice.dismissed].
Future<RatePromptChoice> showRatePromptSheet(BuildContext context) async {
  final RatePromptChoice? choice = await showPrismSheet<RatePromptChoice>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Enjoying Prism?', style: PrismTextStyles.cardTitle(sheetContext)),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(RatePromptChoice.notReally),
                  child: const Text('Not really'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(RatePromptChoice.yes),
                  child: const Text('Yes'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return choice ?? RatePromptChoice.dismissed;
}
