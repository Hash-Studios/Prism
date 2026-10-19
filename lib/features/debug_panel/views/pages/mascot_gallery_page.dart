import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
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

  String _useCase(GlintMood mood, AppLocalizations l10n) => switch (mood) {
    GlintMood.calm => l10n.debugEmptyList,
    GlintMood.happy => l10n.debugWallpaperSetSaved,
    GlintMood.celebrate => l10n.debugStreakCoinsPurchase,
    GlintMood.love => l10n.debugFavouriteAdded,
    GlintMood.surprised => l10n.debugWotdNotification,
    GlintMood.curious => l10n.debugLoadingSearch,
    GlintMood.proud => l10n.debugStreakKeptToday,
    GlintMood.worried => l10n.debugOfflineStreakRisk,
    GlintMood.sad => l10n.debugErrorStreakLost,
    GlintMood.sleepy => l10n.debugNothingNew,
  };

  String _moodLabel(GlintMood mood, AppLocalizations l10n) => switch (mood) {
    GlintMood.calm => l10n.debugMoodCalm,
    GlintMood.happy => l10n.debugMoodHappy,
    GlintMood.celebrate => l10n.debugMoodCelebrate,
    GlintMood.love => l10n.debugMoodLove,
    GlintMood.surprised => l10n.debugMoodSurprised,
    GlintMood.curious => l10n.debugMoodCurious,
    GlintMood.proud => l10n.debugMoodProud,
    GlintMood.worried => l10n.debugMoodWorried,
    GlintMood.sad => l10n.debugMoodSad,
    GlintMood.sleepy => l10n.debugMoodSleepy,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    // The card colour is data: it checks Glint on both a light and a dark surface, whatever the theme.
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrismGroup(
                      children: [
                        PrismSwitchRow(
                          title: context.l10n.debugStillPoses,
                          subtitle: context.l10n.debugReduceMotionPose,
                          value: _still,
                          onChanged: (bool v) => setState(() => _still = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: PrismSpace.sm),
                    PrismSegmented<bool>(
                      values: const <bool>[false, true],
                      selected: _darkCard,
                      labelOf: (bool dark) => dark ? context.l10n.debugDarkCard : context.l10n.debugLightCard,
                      onChanged: (bool v) => setState(() => _darkCard = v),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
              sliver: MediaQuery(
                data: mediaQuery.copyWith(disableAnimations: mediaQuery.disableAnimations || _still),
                child: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisExtent: 128 + mediaQuery.textScaler.scale(52),
                    mainAxisSpacing: PrismSpace.sm,
                    crossAxisSpacing: PrismSpace.sm,
                  ),
                  delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
                    final GlintMood mood = GlintMood.values[index];
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Glint(mood: mood, size: 120),
                              ),
                            ),
                            const SizedBox(height: PrismSpace.xxs),
                            Text(
                              _moodLabel(mood, context.l10n),
                              style: PrismTextStyles.rowTitle(context).copyWith(color: label),
                            ),
                            Text(
                              _useCase(mood, context.l10n),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: PrismTextStyles.caption(context).copyWith(color: label.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
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
