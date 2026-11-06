import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/data/categories/category_cover.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A term Prism learned from the user, as a plain pill. The sheet lists terms strongest first, so the order carries the
/// strength; screen readers also hear it as a percent.
class LearnedPill extends StatelessWidget {
  const LearnedPill({super.key, required this.term, required this.strength});

  final String term;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String label = '${term[0].toUpperCase()}${term.substring(1)}';
    return Semantics(
      label: context.l10n.wallpaperInterestLearnedLabel(label, (strength * 100).round()),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(PrismRadius.pill),
        ),
        child: Padding(
          padding: PrismBottomSheet.learnedPillPadding,
          child: Text(label, style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14)),
        ),
      ),
    );
  }
}

const double _selectedRingWidth = 2.5;

/// The scrim darkens the lower 55% of a tile to this, so a white label reads on pale photos too.
const double _scrimAlpha = 0.75;
const List<Shadow> _labelShadows = <Shadow>[Shadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 1))];

/// One interest to pick: a photo with its name over a bottom scrim. Selected tiles get a 2.5 point accent ring drawn over
/// the photo and a filled accent tick. The tile keeps its size, so the grid never shifts.
class InterestTile extends StatelessWidget {
  const InterestTile({super.key, required this.interest, required this.selected, required this.onTap});

  final PersonalizedInterest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String displayName = categoryDisplayName(interest.name, context.l10n);
    const BorderRadius radius = BorderRadius.all(Radius.circular(PrismRadius.sm));
    final Duration fast = context.motion(PrismDurations.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.wallpaperInterestSelectedLabel(
        displayName,
        selected ? context.l10n.wallpaperSelected : context.l10n.wallpaperNotSelected,
      ),
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.97,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int decodeWidth = (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round();
                  final String? asset = bundledCoverAsset(interest.imageUrl);
                  if (asset != null) return Image.asset(asset, cacheWidth: decodeWidth, fit: BoxFit.cover);
                  return CachedNetworkImage(
                    imageUrl: interest.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: decodeWidth,
                    fadeInDuration: fast,
                    placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
                  );
                },
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0, -0.1),
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: _scrimAlpha),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: PrismBottomSheet.interestTileLabelInset,
                right: PrismBottomSheet.interestTileLabelInset,
                bottom: PrismBottomSheet.interestTileLabelInset,
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.rowTitle(
                    context,
                  ).copyWith(fontSize: 14, color: Colors.white, shadows: _labelShadows),
                ),
              ),
              AnimatedContainer(
                duration: fast,
                curve: PrismCurves.enter,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: selected ? cs.primary : cs.primary.withValues(alpha: 0),
                    width: _selectedRingWidth,
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
    );
  }
}
