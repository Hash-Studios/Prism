import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Why a submission was rejected: a hairline, a small label and the reviewer's reason in full contrast.
class RejectionFeedback extends StatelessWidget {
  const RejectionFeedback({super.key, required this.reason});

  final String? reason;

  static const String fallbackReason =
      'No specific reason was provided. Check your wallpaper details, then upload it again.';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String feedback = reason?.trim().isNotEmpty == true ? reason!.trim() : fallbackReason;
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
            child: Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          Text('Why it was rejected', style: PrismTextStyles.caption(context)),
          const SizedBox(height: PrismSpace.xxs),
          Text(feedback, style: PrismTextStyles.body(context).copyWith(color: cs.onSurface, height: 1.4)),
        ],
      ),
    );
  }
}
