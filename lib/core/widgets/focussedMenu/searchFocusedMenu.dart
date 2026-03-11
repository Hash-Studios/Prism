import 'package:Prism/core/wallpaper/wallpaper_action_payload.dart';
import 'package:Prism/core/widgets/focussedMenu/focused_menu_data.dart';
import 'package:Prism/core/widgets/focussedMenu/focused_menu_overlay.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class SearchFocusedMenuHolder extends StatefulWidget {
  const SearchFocusedMenuHolder.payload({super.key, required this.payload, required this.child});

  final WallpaperActionPayload payload;
  final Widget child;

  @override
  _SearchFocusedMenuHolderState createState() => _SearchFocusedMenuHolderState();
}

class _SearchFocusedMenuHolderState extends State<SearchFocusedMenuHolder> {
  final GlobalKey containerKey = GlobalKey();
  late FocusedMenuData _menuData;

  (Offset, Size)? _getOffsetAndSize() {
    final renderBox = (containerKey.currentContext!.findRenderObject() as RenderBox?)!;
    return (renderBox.localToGlobal(Offset.zero), renderBox.size);
  }

  @override
  void initState() {
    super.initState();
    _menuData = FocusedMenuDataAdapter.fromPayload(widget.payload);
  }

  @override
  void didUpdateWidget(covariant SearchFocusedMenuHolder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload != widget.payload) {
      _menuData = FocusedMenuDataAdapter.fromPayload(widget.payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: containerKey,
      children: <Widget>[
        widget.child,
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            onTap: () async {
              final placement = _getOffsetAndSize();
              if (placement == null) {
                return;
              }
              final (childOffset, childSize) = placement;
              await Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 200),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: FocusedMenuOverlay(
                        menuData: _menuData,
                        childOffset: childOffset,
                        childSize: childSize,
                        child: widget.child,
                      ),
                    );
                  },
                  fullscreenDialog: true,
                  opaque: false,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                child: Icon(JamIcons.more_horizontal, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
