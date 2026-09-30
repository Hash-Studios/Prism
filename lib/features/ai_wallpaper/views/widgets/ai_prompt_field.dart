import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_field.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The description field, the hero of the compose state, with two helpers under it.
class AiPromptField extends StatelessWidget {
  const AiPromptField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.maxChars,
    required this.enabled,
    required this.onShuffle,
    required this.onSceneIdea,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxChars;
  final bool enabled;
  final VoidCallback onShuffle;
  final VoidCallback onSceneIdea;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismTextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          hint: 'Describe a scene',
          minLines: 4,
          maxLines: 6,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(maxChars)],
        ),
        const SizedBox(height: PrismSpace.xs),
        Wrap(
          spacing: PrismSpace.xs,
          children: <Widget>[
            Tooltip(
              message: 'Shuffle a new example description',
              child: PrismButton(
                label: 'Shuffle',
                icon: Icons.shuffle_rounded,
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: enabled ? onShuffle : null,
              ),
            ),
            Tooltip(
              message: 'Use this scene in your description (editable)',
              child: PrismButton(
                label: 'Scene idea',
                icon: Icons.lightbulb_outline_rounded,
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: enabled ? onSceneIdea : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
