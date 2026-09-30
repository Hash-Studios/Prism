import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:flutter/material.dart';

/// Debug tab: every [GlintMood], moving or as its still pose, on a light or dark card.
class MascotGalleryPage extends StatefulWidget {
  const MascotGalleryPage({super.key});

  @override
  State<MascotGalleryPage> createState() => _MascotGalleryPageState();
}

class _MascotGalleryPageState extends State<MascotGalleryPage> {
  bool _still = false;
  bool _darkCard = true;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Color card = _darkCard ? Colors.black : Colors.white;
    final Color label = _darkCard ? Colors.white : Colors.black;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int maxColumns = constraints.maxWidth > 600 ? 3 : 2;
        final double scaledLabelWidth = mediaQuery.textScaler.scale(72);
        final double cellWidth = scaledLabelWidth > 120 ? scaledLabelWidth : 120;
        final int crossAxisCount = ((constraints.maxWidth - 32 + 12) / (cellWidth + 12)).floor().clamp(1, maxColumns);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
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
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: MediaQuery(
                data: mediaQuery.copyWith(disableAnimations: mediaQuery.disableAnimations || _still),
                child: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: 128 + mediaQuery.textScaler.scale(30),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
                    final GlintMood mood = GlintMood.values[index];
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outline.withValues(alpha: .3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Glint(mood: mood, size: 120),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mood.name,
                            style: TextStyle(color: label, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }, childCount: GlintMood.values.length),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
