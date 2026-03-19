import 'package:flutter/material.dart';

class PersonalizedEmptyCard extends StatelessWidget {
  const PersonalizedEmptyCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.14)),
      ),
      child: Center(
        child: Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}
