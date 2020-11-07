import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenuDetails.dart';
import 'package:flutter/material.dart';

class FocusedMenuHolder extends StatefulWidget {
  final String provider;
  final Widget child;
  final int index;

  const FocusedMenuHolder(
      {@required this.provider, @required this.child, @required this.index});

  @override
  _FocusedMenuHolderState createState() => _FocusedMenuHolderState();
}

class _FocusedMenuHolderState extends State<FocusedMenuHolder> {
  GlobalKey containerKey = GlobalKey();
  Offset childOffset = const Offset(0, 0);
  Size childSize;

  void getOffset() {
    final RenderBox renderBox =
        containerKey.currentContext.findRenderObject() as RenderBox;
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
        Data.subPrismWalls == []
            ? Container()
            : Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () async {
                    getOffset();
                    await Navigator.push(
                        context,
                        PageRouteBuilder(
                            transitionDuration:
                                const Duration(milliseconds: 200),
                            pageBuilder:
                                (context, animation, secondaryAnimation) {
                              animation = Tween(begin: 0.0, end: 1.0)
                                  .animate(animation);
                              return FadeTransition(
                                  opacity: animation,
                                  child: FocusedMenuDetails(
                                    provider: widget.provider,
                                    childOffset: childOffset,
                                    childSize: childSize,
                                    index: widget.index,
                                    size: MediaQuery.of(context).size,
                                    orientation:
                                        MediaQuery.of(context).orientation,
                                    child: widget.child,
                                  ));
                            },
                            fullscreenDialog: true,
                            opaque: false));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).hintColor,
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
