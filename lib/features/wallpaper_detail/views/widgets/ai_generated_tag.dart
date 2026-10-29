import 'dart:async';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

/// Moderator-facing text. Not localized on purpose.
const String kWrongAiLabelDetails = 'Wrong AI label';

/// Walls store the provider's model id, such as `openai/gpt-image-2.5/sunburst/text-to-image`. Keys are id prefixes.
const Map<String, String> _aiModelNames = <String, String>{
  'openai/gpt-image-2.5': 'GPT Image 2.5',
  'fal-ai/bytedance/seedream/v5/lite': 'Seedream 5 Lite',
  'fal-ai/bytedance/seedream/v4.5': 'Seedream 4.5',
  'fal-ai/z-image/turbo': 'Z-Image Turbo',
  'fal-ai/flux/schnell': 'FLUX.1 schnell',
  'gemini-2.5-flash-image': 'Gemini 2.5 Flash Image',
};

/// The readable name of an AI model id, or null for an unknown id so the sheet never shows a raw provider path.
String? aiModelDisplayName(String? modelId) {
  if (modelId == null) return null;
  for (final MapEntry<String, String> entry in _aiModelNames.entries) {
    if (modelId.startsWith(entry.key)) return entry.value;
  }
  return null;
}

/// The "AI-generated" tag on the wall detail screen. Tap opens a sheet that names the model and lets the user report
/// a wrong label. Without [reportDocId] (a bundled wall) the sheet has no report row.
class AiGeneratedTag extends StatelessWidget {
  const AiGeneratedTag({super.key, required this.wallpaper, this.reportDocId, this.reportSubtitle});

  final PrismWallpaper wallpaper;
  final String? reportDocId;
  final String? reportSubtitle;

  void _open(BuildContext context) {
    PrismHaptics.tap();
    final String? docId = reportDocId;
    final String? model = aiModelDisplayName(wallpaper.aiModel);
    unawaited(
      showPrismSheet<void>(
        context,
        builder: (BuildContext sheetContext) {
          return PrismSheetBody(
            title: sheetContext.l10n.wallpaperAiGenerated,
            message: model == null
                ? sheetContext.l10n.wallpaperAiMadeWithUnknown
                : sheetContext.l10n.wallpaperAiMadeWith(model),
            child: docId == null || docId.isEmpty
                ? null
                : PrismGroup(
                    children: <Widget>[
                      PrismRow(
                        icon: JamIcons.flag,
                        title: sheetContext.l10n.wallpaperAiReportWrongLabel,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(
                            showContentReportSheet(
                              context,
                              contentType: 'wall',
                              targetFirestoreDocId: docId,
                              subtitle: reportSubtitle,
                              initialReason: 'other',
                              initialDetails: kWrongAiLabelDetails,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String label = context.l10n.wallpaperAiGenerated;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: PrismTag(label: label, icon: Icons.auto_awesome_rounded),
          ),
        ),
      ),
    );
  }
}
