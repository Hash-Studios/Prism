import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class CoinGateOption<T> {
  const CoinGateOption({required this.label, required this.value, this.outlined = false});

  final String label;
  final T value;
  final bool outlined;
}

/// Bottom sheet for a coin-gated action. Pops with the chosen option's value.
Future<T?> showCoinGateSheet<T>(
  BuildContext context, {
  required String title,
  required int cost,
  required String Function(int missing) message,
  required List<CoinGateOption<T>> options,
}) {
  return showPrismSheet<T>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      final int missing = (cost - CoinsService.instance.balanceNotifier.value).clamp(0, cost);
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).hintColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              if (missing > 0) ...[const Glint(mood: GlintMood.worried, size: 72), const SizedBox(height: 8)],
              Text(title, style: PrismTextStyles.sheetHeadline(sheetContext)),
              const SizedBox(height: 10),
              Text(message(missing), textAlign: TextAlign.center, style: PrismTextStyles.body(sheetContext)),
              const SizedBox(height: 16),
              for (final (int index, CoinGateOption<T> option) in options.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: option.outlined
                      ? OutlinedButton(
                          onPressed: () {
                            PrismHaptics.tap();
                            Navigator.of(sheetContext).pop(option.value);
                          },
                          child: Text(option.label),
                        )
                      : FilledButton(
                          onPressed: () {
                            PrismHaptics.tap();
                            Navigator.of(sheetContext).pop(option.value);
                          },
                          child: Text(option.label),
                        ),
                ),
              ],
              if (missing > 0) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    PrismHaptics.tap();
                    final StackRouter router = context.router;
                    Navigator.of(sheetContext).pop();
                    router.pushPath('/rewards');
                  },
                  child: const Text('Earn coins'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
