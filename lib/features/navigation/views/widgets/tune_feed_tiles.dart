import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A term Prism learned from the user, as a pill with a bar for how strong the signal is.
class LearnedPill extends StatelessWidget {
  const LearnedPill({super.key, required this.term, required this.strength});

  final String term;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String label = '${term[0].toUpperCase()}${term.substring(1)}';
    const BorderRadius barRadius = BorderRadius.all(Radius.circular(PrismBottomSheet.dragHandleRadius));
    return Semantics(
      label: 'Learned: $label, ${(strength * 100).round()} percent',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.06), borderRadius: barRadius),
        child: Padding(
          padding: PrismBottomSheet.learnedPillPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14)),
              const SizedBox(height: PrismSpace.xs),
              Container(
                width: PrismBottomSheet.learnedBarWidth,
                height: PrismBottomSheet.learnedBarHeight,
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: PrismBottomSheet.learnedBarTrackAlpha),
                  borderRadius: barRadius,
                ),
                child: FractionallySizedBox(
                  widthFactor: strength,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: cs.primary, borderRadius: barRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One interest to pick: a photo with its name. Selected tiles get a 2 point accent border and a tick.
class InterestTile extends StatelessWidget {
  const InterestTile({super.key, required this.interest, required this.selected, required this.onTap});

  final PersonalizedInterest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    const BorderRadius radius = BorderRadius.all(Radius.circular(PrismRadius.sm));
    final Duration fast = context.motion(PrismDurations.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Interest: ${interest.name}, ${selected ? 'selected' : 'not selected'}',
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.97,
        child: AnimatedScale(
          scale: selected ? PrismBottomSheet.interestTileSelectedScale : 1,
          duration: fast,
          curve: PrismCurves.enter,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) => CachedNetworkImage(
                    imageUrl: interest.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round(),
                    fadeInDuration: fast,
                    placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const <double>[0.4, 1],
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: PrismBottomSheet.interestTileScrimAlpha),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: PrismBottomSheet.interestTileLabelInset,
                  right: PrismBottomSheet.interestTileLabelInset,
                  bottom: PrismBottomSheet.interestTileLabelInset,
                  child: Text(
                    interest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14, color: Colors.white),
                  ),
                ),
                AnimatedContainer(
                  duration: fast,
                  curve: PrismCurves.enter,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: selected ? cs.primary : cs.primary.withValues(alpha: 0),
                      width: PrismBottomSheet.interestTileSelectedBorderWidth,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: PrismBottomSheet.interestTileLabelInset,
                  end: PrismBottomSheet.interestTileLabelInset,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0.9,
                    duration: fast,
                    curve: PrismCurves.pop,
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: fast,
                      child: Container(
                        width: PrismBottomSheet.interestCheckBadgeSize,
                        height: PrismBottomSheet.interestCheckBadgeSize,
                        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        child: Icon(
                          Icons.check_rounded,
                          size: PrismBottomSheet.interestCheckIconSize,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
