import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Under the result: save and refine as buttons, set and submit as icons.
class AiResultActions extends StatelessWidget {
  const AiResultActions({
    super.key,
    required this.showSet,
    required this.showRefine,
    required this.canSubmit,
    required this.onSet,
    required this.onSave,
    required this.onRefine,
    required this.onSubmit,
  });

  final bool showSet;
  final bool showRefine;
  final bool canSubmit;
  final VoidCallback onSet;
  final VoidCallback onSave;
  final VoidCallback onRefine;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: PrismButton(label: 'Save', onPressed: onSave, expand: true),
        ),
        if (showRefine) ...<Widget>[
          const SizedBox(width: PrismSpace.xs),
          Expanded(
            child: PrismButton(label: 'Refine', variant: PrismButtonVariant.tonal, onPressed: onRefine, expand: true),
          ),
        ],
        if (showSet) ...<Widget>[
          const SizedBox(width: PrismSpace.xs),
          PrismIconButton(icon: Icons.wallpaper_rounded, tooltip: 'Set as wallpaper', onPressed: onSet, filled: true),
        ],
        if (canSubmit) ...<Widget>[
          const SizedBox(width: PrismSpace.xs),
          Semantics(
            button: true,
            label: 'Submit wallpaper for community review',
            excludeSemantics: true,
            onTap: onSubmit,
            child: PrismIconButton(
              icon: Icons.upload_rounded,
              tooltip: 'Submit for community review',
              onPressed: onSubmit,
              filled: true,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shown when a submission may have gone through but was not confirmed.
class AiUnconfirmedNotice extends StatelessWidget {
  const AiUnconfirmedNotice({super.key, required this.onCheck});

  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xs, PrismSpace.xs, PrismSpace.xs),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_rounded, size: 20, color: PrismColors.warning),
          const SizedBox(width: PrismSpace.sm),
          Expanded(
            child: Text(
              'Submission status is unconfirmed. Check before retrying.',
              style: PrismTextStyles.body(context),
            ),
          ),
          PrismButton(
            label: 'Check status',
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            onPressed: onCheck,
          ),
        ],
      ),
    );
  }
}
