import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:flutter/material.dart';

class ProfileCompletenessCard extends StatelessWidget {
  const ProfileCompletenessCard({super.key, required this.status, this.onCompleteNow});

  final ProfileCompletenessStatus status;
  final Future<void> Function()? onCompleteNow;

  @override
  Widget build(BuildContext context) {
    if (status.isComplete) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: status.progress,
                        strokeWidth: 6,
                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.error),
                      ),
                      Center(
                        child: Text(
                          '${status.percent}%',
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile completeness',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${status.completedSteps}/${status.totalSteps} completed • Earn 25 coins at 100%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...status.missingSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_unchecked, size: 14, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(step.label, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: onCompleteNow == null
                    ? null
                    : () async {
                        await onCompleteNow?.call();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE57697),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Complete now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
