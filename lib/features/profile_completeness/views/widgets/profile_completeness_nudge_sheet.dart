import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:flutter/material.dart';

enum ProfileCompletenessNudgeAction { completeNow, notNow }

Future<ProfileCompletenessNudgeAction?> showProfileCompletenessNudgeSheet(
  BuildContext context, {
  required ProfileCompletenessStatus status,
}) {
  return showModalBottomSheet<ProfileCompletenessNudgeAction>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (context) => ProfileCompletenessNudgeSheet(status: status),
  );
}

class ProfileCompletenessNudgeSheet extends StatelessWidget {
  const ProfileCompletenessNudgeSheet({super.key, required this.status});

  final ProfileCompletenessStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(99)),
          ),
          Text(
            'Complete your profile to earn 25 Prism Coins',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'You are ${status.percent}% complete. Add the remaining details to unlock your reward.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...status.missingSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked, size: 14),
                  const SizedBox(width: 8),
                  Text(step.label, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(ProfileCompletenessNudgeAction.completeNow),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57697),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Complete now'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(ProfileCompletenessNudgeAction.notNow),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}
