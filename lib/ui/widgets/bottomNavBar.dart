import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/inheritedScrollControllerProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BottomBar extends StatefulWidget {
  final Widget child;
  const BottomBar({
    this.child,
    Key key,
  }) : super(key: key);

  @override
  _BottomBarState createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar>
    with SingleTickerProviderStateMixin {
  ScrollController scrollBottomBarController = new ScrollController();
  AnimationController _controller;
  Animation<Offset> _offsetAnimation;
  bool isScrollingDown = false;

  @override
  void initState() {
    myScroll();
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 2),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  void showBottomBar() {
    setState(() {
      _controller.reverse();
    });
  }

  void hideBottomBar() {
    setState(() {
      _controller.forward();
    });
  }

  void myScroll() async {
    scrollBottomBarController.addListener(() {
      if (scrollBottomBarController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (!isScrollingDown) {
          isScrollingDown = true;
          hideBottomBar();
        }
      }
      if (scrollBottomBarController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (isScrollingDown) {
          isScrollingDown = false;
          showBottomBar();
        }
      }
    });
  }

  @override
  void dispose() {
    scrollBottomBarController.removeListener(() {});
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        InheritedDataProvider(
          scrollController: scrollBottomBarController,
          child: widget.child,
        ),
        Positioned(
          bottom: 10,
          child: SlideTransition(
            position: _offsetAnimation,
            child: BottomNavBar(),
          ),
        )
      ],
    );
  }
}

class BottomNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
              color: Color(0xFF000000).withOpacity(0.25),
              blurRadius: 4,
              offset: Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(500),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 0, 12),
              child: IconButton(
                icon:
                    Icon(JamIcons.home_f, color: Theme.of(context).accentColor),
                onPressed: () {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                icon:
                    Icon(JamIcons.search, color: Theme.of(context).accentColor),
                onPressed: () {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                icon: Icon(JamIcons.heart_f,
                    color: Theme.of(context).accentColor),
                onPressed: () {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                icon: Icon(JamIcons.instant_picture_f,
                    color: Theme.of(context).accentColor),
                onPressed: () {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 20, 12),
              child: IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(500),
                      color: Theme.of(context).accentColor),
                  child: Icon(JamIcons.user_circle,
                      color: Theme.of(context).primaryColor),
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
