import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:flutter/material.dart';

/// A folder's newest covers, laid out so no cell is ever empty. One cover fills the square, two split it, three put
/// the newest on the left half and two on the right, four make a 2x2 grid. No covers shows a folder icon.
class FolderCover extends StatelessWidget {
  const FolderCover({super.key, required this.covers, required this.size, this.radius = PrismRadius.sm});

  final List<String> covers;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> shown = covers.take(folderMaxCovers).toList(growable: false);
    final double gap = size < 64 ? 1 : 2;
    final double half = (size - gap) / 2;
    Widget cell(int index, double width, double height) => SizedBox(
      width: width,
      height: height,
      child: PrismImageTile(url: shown[index], memCacheWidth: (width * 3).round()),
    );
    final Widget body = switch (shown.length) {
      0 => ColoredBox(
        color: cs.onSurface.withValues(alpha: 0.08),
        child: Icon(Icons.folder_rounded, size: size * 0.36, color: cs.onSurfaceVariant),
      ),
      1 => cell(0, size, size),
      2 => Row(
        children: <Widget>[
          cell(0, half, size),
          SizedBox(width: gap),
          cell(1, half, size),
        ],
      ),
      3 => Row(
        children: <Widget>[
          cell(0, half, size),
          SizedBox(width: gap),
          Column(
            children: <Widget>[
              cell(1, half, half),
              SizedBox(height: gap),
              cell(2, half, half),
            ],
          ),
        ],
      ),
      _ => Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              cell(0, half, half),
              SizedBox(width: gap),
              cell(1, half, half),
            ],
          ),
          SizedBox(height: gap),
          Row(
            children: <Widget>[
              cell(2, half, half),
              SizedBox(width: gap),
              cell(3, half, half),
            ],
          ),
        ],
      ),
    };
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.square(dimension: size, child: body),
      ),
    );
  }
}
