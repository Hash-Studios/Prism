import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:flutter/material.dart';

/// "Wallpaper 2 of 3" with one mark per image: sent, not sent, current or waiting.
class UploadBatchStepper extends StatelessWidget {
  const UploadBatchStepper({super.key, required this.batch});

  final UploadBatch batch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String label = 'Wallpaper ${batch.position} of ${batch.total}';
    return Semantics(
      label: '$label. ${batch.submittedCount} submitted.',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Text(label, style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurface)),
          const SizedBox(width: 12),
          for (int i = 0; i < batch.total; i++) ...<Widget>[_mark(colors, i), const SizedBox(width: 6)],
        ],
      ),
    );
  }

  Widget _mark(ColorScheme colors, int i) {
    if (i == batch.index) return Icon(Icons.radio_button_checked, size: 16, color: colors.primary);
    return switch (batch.outcomes[i]) {
      UploadItemOutcome.submitted => Icon(Icons.check_circle, size: 16, color: colors.primary),
      UploadItemOutcome.skipped => Icon(Icons.remove_circle_outline, size: 16, color: colors.onSurfaceVariant),
      UploadItemOutcome.failed => Icon(Icons.error_outline, size: 16, color: colors.error),
      UploadItemOutcome.pending => Icon(Icons.radio_button_unchecked, size: 16, color: colors.onSurfaceVariant),
    };
  }
}
