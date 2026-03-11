import 'package:Prism/core/widgets/focussedMenu/focused_menu_data.dart';
import 'package:Prism/core/widgets/focussedMenu/focused_menu_overlay.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class SearchFocusedMenuHolder extends StatefulWidget {
  final String? selectedProvider;
  final String query;
  final FocusedMenuData? menuData;
  final Widget child;
  final int? index;

  const SearchFocusedMenuHolder({
    super.key,
    required this.selectedProvider,
    required this.query,
    required this.child,
    required this.index,
  }) : menuData = null;

  const SearchFocusedMenuHolder.data({super.key, required this.menuData, required this.child})
    : selectedProvider = null,
      query = '',
      index = null;

  @override
  _SearchFocusedMenuHolderState createState() => _SearchFocusedMenuHolderState();
}

class _SearchFocusedMenuHolderState extends State<SearchFocusedMenuHolder> {
  GlobalKey containerKey = GlobalKey();
  Offset childOffset = Offset.zero;
  Size? childSize;

  void getOffset() {
    final RenderBox renderBox = (containerKey.currentContext!.findRenderObject() as RenderBox?)!;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      childOffset = Offset(offset.dx, offset.dy);
      childSize = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final FocusedMenuData? data =
        widget.menuData ??
        (widget.index == null
            ? null
            : FocusedMenuDataAdapter.fromSearch(provider: widget.selectedProvider, index: widget.index!));

    return Stack(
      key: containerKey,
      children: <Widget>[
        widget.child,
        if (data != null)
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
