import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/utils/string_extensions.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// Opens the list of link types. [values] holds what is already set per type. Resolves the picked type.
Future<ProfileLinkKind?> showLinkKindSheet(
  BuildContext context, {
  required ProfileLinkKind selected,
  required Map<String, String> values,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return showPrismSheet<ProfileLinkKind>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => PrismSheetBody(
      title: 'Link type',
      scrollable: true,
      child: PrismGroup(
        children: <Widget>[
          for (final ProfileLinkKind kind in profileLinkKinds)
            PrismRow(
              icon: kind.icon,
              title: kind.name.inCaps,
              subtitle: (values[kind.name] ?? '').isEmpty ? null : values[kind.name],
              showChevron: false,
              trailing: kind.name == selected.name ? Icon(Icons.check_rounded, size: 22, color: cs.primary) : null,
              onTap: () => Navigator.of(sheetContext).pop(kind),
            ),
        ],
      ),
    ),
  );
}

/// One link input: a compact button for the link type, then the field. The type opens [showLinkKindSheet].
class EditProfileLinkField extends StatelessWidget {
  const EditProfileLinkField({
    super.key,
    required this.kind,
    required this.controller,
    required this.error,
    required this.onPickKind,
    required this.onChanged,
    required this.onRemove,
  });

  final ProfileLinkKind kind;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onPickKind;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: PrismSpace.xxs, bottom: PrismSpace.xs),
          child: Text(
            'Link',
            style: PrismTextStyles.caption(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PressScale(
              child: Semantics(
                button: true,
                label: 'Link type, ${kind.name.inCaps}',
                excludeSemantics: true,
                onTap: onPickKind,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPickKind,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      borderRadius: PrismRadius.field,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(kind.icon, size: 20, color: cs.onSurface),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more_rounded, size: 18, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: PrismSpace.xs),
            Expanded(
              child: PrismTextField(
                controller: controller,
                hint: kind.placeholder.isEmpty ? 'https://' : kind.placeholder,
                error: error,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: onChanged,
                suffix: controller.text.isEmpty
                    ? null
                    : PrismIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Remove link',
                        iconSize: 20,
                        onPressed: onRemove,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
