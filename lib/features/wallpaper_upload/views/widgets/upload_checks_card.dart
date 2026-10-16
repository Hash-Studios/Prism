import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

enum UploadCheckState { pending, active, done }

/// One line of the upload checklist: a status icon and a plain sentence.
class UploadCheck {
  const UploadCheck(this.state, this.text);

  final UploadCheckState state;
  final String text;
}

/// A card that lists the steps of an upload, each with its status.
class UploadChecksCard extends StatelessWidget {
  const UploadChecksCard({super.key, required this.checks});

  final List<UploadCheck> checks;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismCard(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < checks.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            _CheckRow(check: checks[i]),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final UploadCheck check;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget icon = switch (check.state) {
      UploadCheckState.done => const Icon(Icons.check_circle_rounded, size: 22, color: PrismColors.success),
      UploadCheckState.active => SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      ),
      UploadCheckState.pending => Icon(
        Icons.radio_button_unchecked_rounded,
        size: 22,
        color: cs.onSurface.withValues(alpha: 0.3),
      ),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
        child: Row(
          children: <Widget>[
            SizedBox.square(dimension: 24, child: Center(child: icon)),
            const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: Text(
                check.text,
                style: check.state == UploadCheckState.pending
                    ? PrismTextStyles.body(context)
                    : PrismTextStyles.rowTitle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
