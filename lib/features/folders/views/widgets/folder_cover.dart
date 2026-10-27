import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// A 2x2 collage of a folder's newest covers. Empty cells take the neutral fill; no covers shows a folder icon.
class FolderCover extends StatelessWidget {
  const FolderCover({super.key, required this.covers, required this.size, this.radius = PrismRadius.sm});

  final List<String> covers;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fill = cs.onSurface.withValues(alpha: 0.08);
    final double gap = size < 64 ? 1 : 2;
    final double cell = (size - gap) / 2;
    Widget tile(int index) => SizedBox.square(
      dimension: cell,
      child: index < covers.length
          ? PrismImageTile(url: covers[index], memCacheWidth: (cell * 3).round())
          : ColoredBox(color: fill),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(
          dimension: size,
          child: covers.isEmpty
              ? ColoredBox(
                  color: fill,
                  child: Icon(Icons.folder_rounded, size: size * 0.36, color: cs.onSurfaceVariant),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[tile(0), tile(1)]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[tile(2), tile(3)]),
                  ],
                ),
        ),
      ),
    );
  }
}
