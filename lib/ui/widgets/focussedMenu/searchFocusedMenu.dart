import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/focussedMenu/searchFocusedMenuDetails.dart';
import 'package:flutter/material.dart';

class SearchFocusedMenuHolder extends StatefulWidget {
  final String? selectedProvider;
  final String query;
  final Widget child;
  final int index;

  const SearchFocusedMenuHolder(
      {required this.selectedProvider,
      required this.query,
      required this.child,
      required this.index});

  @override
  _SearchFocusedMenuHolderState createState() =>
      _SearchFocusedMenuHolderState();
}

class _SearchFocusedMenuHolderState extends State<SearchFocusedMenuHolder> {
  GlobalKey containerKey = GlobalKey();
  Offset childOffset = const Offset(0, 0);
  Size? childSize;

  void getOffset() {
    final RenderBox renderBox =
        (containerKey.currentContext!.findRenderObject() as RenderBox?)!;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      childOffset = Offset(offset.dx, offset.dy);
      childSize = size;
    });
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
              getOffset();
              await Navigator.push(
                  context,
                  PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 200),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        animation =
                            Tween(begin: 0.0, end: 1.0).animate(animation);
                        return FadeTransition(
                            opacity: animation,
                            child: SearchFocusedMenuDetails(
                              selectedProvider: widget.selectedProvider,
                              query: widget.query,
                              childOffset: childOffset,
                              childSize: childSize,
                              index: widget.index,
                              child: widget.child,
                            ));
                      },
                      fullscreenDialog: true,
                      opaque: false));
            },
            child: Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).backgroundColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20))),
              padding: const EdgeInsets.all(0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                child: Icon(
                  JamIcons.more_horizontal,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}
