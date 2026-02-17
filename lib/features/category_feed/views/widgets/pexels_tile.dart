import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/features/category_feed/views/widgets/pexels_grid.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PexelsTile extends StatelessWidget {
  const PexelsTile({
    super.key,
    required this.widget,
    required this.index,
  });

  final PexelsGrid widget;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: PData.wallsP.isEmpty
              ? BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                )
              : BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                      image: CachedNetworkImageProvider(PData.wallsP[index].src!["medium"].toString()),
                      fit: BoxFit.cover)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              onTap: () {
                if (PData.wallsP == []) {
                } else {
                  context.pushNamedRoute(wallpaperRoute,
                      arguments: [widget.provider, index, PData.wallsP[index].src!["small"]]);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
