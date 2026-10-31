import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_duo_composition.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

class AiDuoFields extends StatelessWidget {
  const AiDuoFields({super.key, required this.folded, required this.revealed, required this.enabled});

  final TextEditingController folded;
  final TextEditingController revealed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.duoPresetNotice, style: PrismTextStyles.caption(context)),
        const SizedBox(height: PrismSpace.md),
        TextField(
          controller: folded,
          enabled: enabled,
          maxLength: AiDuoComposition.maxPromptChars,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: l10n.duoFoldedPromptLabel, hintText: l10n.duoFoldedPromptExample),
        ),
        const SizedBox(height: PrismSpace.sm),
        TextField(
          controller: revealed,
          enabled: enabled,
          maxLength: AiDuoComposition.maxPromptChars,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: l10n.duoRevealedPromptLabel, hintText: l10n.duoRevealedPromptExample),
        ),
      ],
    );
  }
}
