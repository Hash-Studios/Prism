import 'package:Prism/core/coins/coins_service.dart';
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
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Theme.of(context).primaryColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      final int missing = (cost - CoinsService.instance.balanceNotifier.value).clamp(0, cost);
      return Padding(
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
            Text(title, style: Theme.of(sheetContext).textTheme.displaySmall),
            const SizedBox(height: 10),
            Text(message(missing), textAlign: TextAlign.center, style: Theme.of(sheetContext).textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (final (int index, CoinGateOption<T> option) in options.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: option.outlined
                    ? OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(option.value),
                        child: Text(option.label),
                      )
                    : FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(option.value),
                        child: Text(option.label),
                      ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
