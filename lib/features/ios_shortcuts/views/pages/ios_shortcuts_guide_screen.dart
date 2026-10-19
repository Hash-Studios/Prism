import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

List<String> shortcutsGuideSteps(AppLocalizations l10n) => <String>[
  l10n.wallpaperShortcutsOpenAutomationSteps,
  l10n.wallpaperShortcutsChooseTriggerSteps,
  l10n.wallpaperShortcutsAddActionsSteps,
  l10n.wallpaperShortcutsDisableConfirmationSteps,
];

List<(String, String)> shortcutsGuideSources(AppLocalizations l10n) => <(String, String)>[
  (l10n.wallpaperShortcutsSourceWotd, l10n.wallpaperShortcutsSourceWotdDescription),
  (l10n.wallpaperShortcutsSourceFavourite, l10n.wallpaperShortcutsSourceFavouriteDescription),
];

@RoutePage()
class IosShortcutsGuideScreen extends StatelessWidget {
  const IosShortcutsGuideScreen({super.key});

  Future<void> _openShortcuts(BuildContext context) async {
    PrismHaptics.selection();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    bool opened = false;
    try {
      opened = await launchUrl(Uri.parse('shortcuts://'), mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      logger.w('Could not open Shortcuts', error: error, stackTrace: stackTrace);
    }
    if (opened) return;
    messenger.showSnackBar(SnackBar(content: Text(context.l10n.wallpaperShortcutsOpenError)));
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.wallpaperShortcutsTitle,
      bottomBar: PrismButton(
        label: context.l10n.wallpaperShortcutsOpenAction,
        icon: Icons.open_in_new_rounded,
        expand: true,
        onPressed: () => _openShortcuts(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
        children: <Widget>[
          Text(context.l10n.wallpaperShortcutsHeadline, style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          Text(context.l10n.wallpaperShortcutsBody, style: PrismTextStyles.body(context)),
          PrismSectionHeader(title: context.l10n.wallpaperShortcutsSteps),
          PrismCard(
            child: Column(
              children: <Widget>[
                for (final (int index, String step) in shortcutsGuideSteps(context.l10n).indexed)
                  _StepRow(number: index + 1, text: step),
              ],
            ),
          ),
          PrismSectionHeader(title: context.l10n.wallpaperShortcutsChoosePrismData),
          PrismGroup(
            children: <Widget>[
              for (final (String name, String detail) in shortcutsGuideSources(context.l10n))
                PrismRow(icon: Icons.photo_outlined, title: name, subtitle: detail),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 12,
            backgroundColor: cs.primary.withValues(alpha: 0.14),
            child: Text(
              '$number',
              style: PrismTextStyles.caption(context).copyWith(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: PrismSpace.sm),
          Expanded(
            child: Text(text, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
