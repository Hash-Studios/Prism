import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/focussedMenu/searchFocusedMenuDetails.dart';
import 'package:flutter/material.dart';

class SearchFocusedMenuHolder extends StatefulWidget {
  final String selectedProvider;
  final String query;
  final Widget child;
  final int index;

  const SearchFocusedMenuHolder(
      {Key key,
      @required this.selectedProvider,
      @required this.query,
      @required this.child,
      @required this.index});

  @override
  _SearchFocusedMenuHolderState createState() =>
      _SearchFocusedMenuHolderState();
}

class _SearchFocusedMenuHolderState extends State<SearchFocusedMenuHolder> {
  GlobalKey containerKey = GlobalKey();
  Offset childOffset = Offset(0, 0);
  Size childSize;

  getOffset() {
    RenderBox renderBox = containerKey.currentContext.findRenderObject();
    Size size = renderBox.size;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      this.childOffset = Offset(offset.dx, offset.dy);
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
            child: Container(
              decoration: BoxDecoration(
                  color: Color(0xFF2F2F2F),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20))),
              padding: EdgeInsets.all(0),
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                child: Icon(
                  JamIcons.more_horizontal,
                  color: Colors.white,
                ),
              ),
            ),
            onTap: () async {
              getOffset();
              await Navigator.push(
                  context,
                  PageRouteBuilder(
                      transitionDuration: Duration(milliseconds: 200),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        animation =
                            Tween(begin: 0.0, end: 1.0).animate(animation);
                        return FadeTransition(
                            opacity: animation,
                            child: SearchFocusedMenuDetails(
                              selectedProvider: widget.selectedProvider,
                              query: widget.query,
                              child: widget.child,
                              childOffset: childOffset,
                              childSize: childSize,
                              index: widget.index,
                            ));
                      },
                      fullscreenDialog: true,
                      opaque: false));
            },
          ),
        )
      ],
    );
  }
}
