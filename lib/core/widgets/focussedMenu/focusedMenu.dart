import 'package:Prism/core/widgets/focussedMenu/focused_menu_data.dart';
import 'package:Prism/core/widgets/focussedMenu/focused_menu_overlay.dart';
import 'package:Prism/core/wallpaper/wallpaper_action_payload.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class FocusedMenuHolder extends StatefulWidget {
  const FocusedMenuHolder.payload({super.key, required this.payload, required this.child});

  final WallpaperActionPayload payload;
  final Widget child;

  @override
  _FocusedMenuHolderState createState() => _FocusedMenuHolderState();
}

class _FocusedMenuHolderState extends State<FocusedMenuHolder> {
  final GlobalKey containerKey = GlobalKey();
  Offset childOffset = Offset.zero;
  Size? childSize;

  void getOffset() {
    final renderBox = (containerKey.currentContext!.findRenderObject() as RenderBox?)!;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      childOffset = Offset(offset.dx, offset.dy);
      childSize = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = FocusedMenuDataAdapter.fromPayload(widget.payload);
    return Stack(
      key: containerKey,
      children: <Widget>[
        widget.child,
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            onTap: () async {
              getOffset();
              if (childSize == null) {
                return;
              }
              await Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 200),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: FocusedMenuOverlay(
                        menuData: data,
                        childOffset: childOffset,
                        childSize: childSize!,
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
