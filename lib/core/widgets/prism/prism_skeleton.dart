import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Skeleton placeholders for content that is loading. Shapes match the content they stand in for, so the page does
/// not jump when the data arrives. Wrap a group in one [PrismSkeleton] so all blocks pulse together.
class PrismSkeleton extends StatelessWidget {
  const PrismSkeleton({super.key, required this.child});

  /// A list of [rows] avatar-and-two-lines rows: people, notifications, transactions.
  factory PrismSkeleton.rows({Key? key, int rows = 8, bool avatar = true, EdgeInsetsGeometry? padding}) {
    return PrismSkeleton(
      key: key,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
        itemCount: rows,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              if (avatar) ...<Widget>[const PrismBone.circle(size: 44), const SizedBox(width: PrismSpace.sm)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PrismBone(width: 120.0 + (i % 3) * 36),
                    const SizedBox(height: PrismSpace.xs),
                    PrismBone(width: 200.0 - (i % 2) * 40, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A stack of [count] card-shaped blocks.
  factory PrismSkeleton.cards({Key? key, int count = 3, double height = 120, EdgeInsetsGeometry? padding}) {
    return PrismSkeleton(
      key: key,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.sm),
        itemBuilder: (_, _) => PrismBone(height: height, radius: PrismRadius.lg),
      ),
    );
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(child: PulsePlaceholder(builder: (context, _) => child)),
    );
  }
}

/// One skeleton block. Put it under a [PrismSkeleton].
class PrismBone extends StatelessWidget {
  const PrismBone({super.key, this.width, this.height = 14, this.radius = 6});

  const PrismBone.circle({super.key, required double size}) : width = size, height = size, radius = 999;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: PulseFill(borderRadius: BorderRadius.circular(radius)),
    );
  }
}
