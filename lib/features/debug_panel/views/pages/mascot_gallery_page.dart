import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:flutter/material.dart';

/// Debug tab: every [GlintMood], moving or as its still pose, on a light or dark card.
class MascotGalleryPage extends StatefulWidget {
  const MascotGalleryPage({super.key});

  @override
  State<MascotGalleryPage> createState() => _MascotGalleryPageState();
}

class _MascotGalleryPageState extends State<MascotGalleryPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _still = false;
  bool _darkCard = true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color card = _darkCard ? Colors.black : Colors.white;
    final Color label = _darkCard ? Colors.white : Colors.black;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Still poses'),
          subtitle: const Text('Shows the reduce-motion pose of each mood'),
          value: _still,
          onChanged: (bool v) => setState(() => _still = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Light card')),
              ButtonSegment(value: true, label: Text('Dark card')),
            ],
            selected: {_darkCard},
            onSelectionChanged: (Set<bool> v) => setState(() => _darkCard = v.first),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: _still),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) => GridView.count(
                crossAxisCount: constraints.maxWidth > 600 ? 3 : 2,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final GlintMood mood in GlintMood.values)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outline.withValues(alpha: .3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Glint(mood: mood, size: 120),
                          const SizedBox(height: 8),
                          Text(
                            mood.name,
                            style: TextStyle(color: label, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
