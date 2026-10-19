import 'dart:ui' show ImageFilter;

import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The home carousel page for a live Drop: frosted cover art on obsidian, the title, the countdown and a Preview pill.
class DropCarouselSlide extends StatelessWidget {
  const DropCarouselSlide({super.key, required this.drop, required this.now, required this.onTap, this.memCacheHeight});

  final DropEntity drop;
  final DateTime now;
  final VoidCallback onTap;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final bool lastCall = drop.phaseAt(now) == DropPhase.lastCall;
    final String cover = drop.walls.isEmpty ? '' : drop.walls.first.thumb;
    final String detail = '${drop.count} walls · ${drop.endsInLabel(now)}';
    final BorderRadius radius = BorderRadius.circular(PrismRadius.lg);
    const double inset = 8;
    final TextStyle eyebrow = PrismTextStyles.eyebrow(context).copyWith(color: DropPalette.gold, letterSpacing: 2.4);
    return PressScale(
      scale: 0.98,
      child: Semantics(
        button: true,
        label: 'The Drop, ${drop.title}, $detail${lastCall ? ', last call' : ''}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const ColoredBox(color: DropPalette.obsidian),
                  if (cover.isNotEmpty)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.mirror),
                      child: Transform.scale(
                        scale: 1.2,
                        child: PrismImageTile(url: cover, memCacheHeight: memCacheHeight),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          DropPalette.obsidian.withValues(alpha: 0.35),
                          DropPalette.obsidian.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(inset),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(PrismRadius.lg - inset),
                        border: Border.all(color: DropPalette.gold.withValues(alpha: 0.5), width: 0.5),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(PrismSpace.lg, PrismSpace.md, PrismSpace.lg, PrismSpace.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text('THE DROP', style: eyebrow),
                            if (lastCall) ...<Widget>[
                              const SizedBox(width: PrismSpace.sm),
                              Text('Last call', style: eyebrow.copyWith(color: DropPalette.urgent, letterSpacing: 0.4)),
                            ],
                          ],
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    drop.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PrismTextStyles.sectionTitle(context).copyWith(color: DropPalette.ink),
                                  ),
                                  const SizedBox(height: PrismSpace.xxs),
                                  Text(
                                    detail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PrismTextStyles.caption(context).copyWith(color: DropPalette.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: PrismSpace.sm),
                            const _PreviewPill(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: DropPalette.gold, borderRadius: BorderRadius.circular(PrismRadius.pill)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: 7),
        child: Text('Preview', style: PrismTextStyles.button.copyWith(fontSize: 13, color: DropPalette.obsidian)),
      ),
    );
  }
}
