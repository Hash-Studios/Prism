import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String _fontFamily = 'Proxima Nova';

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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: 'Change automatically'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'Change your wallpaper automatically',
                    style: TextStyle(
                      color: scheme.secondary,
                      fontFamily: _fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'iPhone lets Shortcuts change the wallpaper for you. Make one automation. It runs on its own.',
                    style: TextStyle(color: scheme.secondary.withValues(alpha: 0.7), fontFamily: _fontFamily),
                  ),
                ),
                _GuideCard(
                  title: 'STEPS',
                  children: [
                    for (int index = 0; index < shortcutsGuideSteps.length; index++)
                      _StepRow(number: index + 1, text: shortcutsGuideSteps[index]),
                  ],
                ),
                _GuideCard(
                  title: 'PICK WHAT PRISM SENDS',
                  children: [
                    for (final (String name, String detail) in shortcutsGuideSources)
                      ListTile(
                        leading: Icon(Icons.photo_outlined, color: scheme.error),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: scheme.secondary,
                            fontWeight: FontWeight.w500,
                            fontFamily: _fontFamily,
                          ),
                        ),
                        subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openShortcuts(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Shortcuts'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: theme.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.error,
                  fontFamily: _fontFamily,
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.error.withValues(alpha: 0.14),
            child: Text(
              '$number',
              style: TextStyle(color: scheme.error, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: _fontFamily),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.secondary, fontFamily: _fontFamily, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
