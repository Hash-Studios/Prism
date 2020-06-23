import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/focusedMenuDetails.dart';
import 'package:Prism/ui/widgets/focusedMenuDetailsP.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FocusedMenuHolder extends StatefulWidget {
  final String provider;
  final Widget child;
  final int index;

  const FocusedMenuHolder(
      {Key key,
      @required this.provider,
      @required this.child,
      @required this.index});

  @override
  _FocusedMenuHolderState createState() => _FocusedMenuHolderState();
}

class _FocusedMenuHolderState extends State<FocusedMenuHolder> {
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
        Provider.of<WallHavenProvider>(context,listen: false).walls == []
            ? Container()
            : Align(
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
                            pageBuilder:
                                (context, animation, secondaryAnimation) {
                              animation = Tween(begin: 0.0, end: 1.0)
                                  .animate(animation);
                              return FadeTransition(
                                  opacity: animation,
                                  child: widget.provider == "WallHaven"
                                      ? FocusedMenuDetails(
                                          child: widget.child,
                                          childOffset: childOffset,
                                          childSize: childSize,
                                          index: widget.index,
                                        )
                                      : FocusedMenuDetailsP(
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
