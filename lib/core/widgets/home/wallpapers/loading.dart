import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:flutter/material.dart';

/// Skeleton for a wallpaper grid. It uses the shared [PrismWallGrid] layout, so content lands where the skeleton was.
class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key, this.childAspectRatio, this.borderRadius = PrismWallGrid.tileRadius, this.columns});

  final double? childAspectRatio;
  final BorderRadius borderRadius;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: PulsePlaceholder(
          builder: (context, _) => GridView.builder(
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: PrismWallGrid.padding,
            itemCount: 18,
            shrinkWrap: true,
            gridDelegate: PrismWallGrid.delegate(context, columns: columns, aspectRatio: childAspectRatio),
            itemBuilder: (context, index) => PulseFill(borderRadius: borderRadius),
          ),
        ),
      ),
    );
  }
}
