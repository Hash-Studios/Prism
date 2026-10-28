import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// The one control row above a Library grid: [leading] (a count or a search field) and the tab's [actions].
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({super.key, required this.leading, this.actions = const <Widget>[]});

  final Widget leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(PrismWallGrid.margin, PrismSpace.xxs, PrismSpace.xxs, PrismSpace.xxs),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(alignment: AlignmentDirectional.centerStart, child: leading),
          ),
          ...actions,
        ],
      ),
    ),
  );
}
