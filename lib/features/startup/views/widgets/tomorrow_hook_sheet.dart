import 'package:flutter/material.dart';

enum TomorrowHookAction { enableReminders, notNow }

Future<TomorrowHookAction?> showTomorrowHookSheet(BuildContext context) {
  return showModalBottomSheet<TomorrowHookAction>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (context) => const _TomorrowHookSheet(),
  );
}

class _TomorrowHookSheet extends StatelessWidget {
  const _TomorrowHookSheet();

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
            'Your first Wall of the Day drops tomorrow morning',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Enable reminders so you never miss the daily featured wallpaper.', style: textTheme.bodyMedium),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(TomorrowHookAction.enableReminders),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57697),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Enable reminders'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(TomorrowHookAction.notNow),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}
