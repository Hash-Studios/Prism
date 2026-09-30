import 'package:flutter/material.dart';

class RejectionFeedback extends StatelessWidget {
  const RejectionFeedback({super.key, required this.reason});

  final String? reason;

  static const String fallbackReason =
      'No specific reason was provided. Please review your submission details before trying again.';

  @override
  Widget build(BuildContext context) {
    final String feedback = reason?.trim().isNotEmpty == true ? reason!.trim() : fallbackReason;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review feedback',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.secondary),
                ),
                Text(
                  feedback,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
