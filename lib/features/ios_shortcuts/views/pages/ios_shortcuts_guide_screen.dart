import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const List<String> shortcutsGuideSteps = <String>[
  'Open the Shortcuts app. Tap Automation, then New Automation.',
  'Pick when it runs: Time of Day, When I open an app, or Charger.',
  'Add the action "Get Prism Wallpaper". Then add the action "Set Wallpaper".',
  'Turn off "Ask Before Running". Tap Done.',
];

const List<(String, String)> shortcutsGuideSources = <(String, String)>[
  ('Wall of the Day', "Today's pick from Prism."),
  ('Random favourite', 'A random wallpaper you hearted. It avoids the one it gave last. Heart some wallpapers first.'),
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
    messenger.showSnackBar(const SnackBar(content: Text('Could not open Shortcuts. Open the app yourself.')));
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Change automatically',
      bottomBar: PrismButton(
        label: 'Open Shortcuts',
        icon: Icons.open_in_new_rounded,
        expand: true,
        onPressed: () => _openShortcuts(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
        children: <Widget>[
          Text('Change your wallpaper automatically', style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          Text(
            'iPhone lets Shortcuts change the wallpaper for you. Make one automation. It runs on its own.',
            style: PrismTextStyles.body(context),
          ),
          const PrismSectionHeader(title: 'Steps'),
          PrismCard(
            child: Column(
              children: <Widget>[
                for (int index = 0; index < shortcutsGuideSteps.length; index++)
                  _StepRow(number: index + 1, text: shortcutsGuideSteps[index]),
              ],
            ),
          ),
          const PrismSectionHeader(title: 'Pick what Prism sends'),
          PrismGroup(
            children: <Widget>[
              for (final (String name, String detail) in shortcutsGuideSources)
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
