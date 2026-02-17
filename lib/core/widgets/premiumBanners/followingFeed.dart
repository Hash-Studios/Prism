import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class PremiumBannerFollowingFeed extends StatelessWidget {
  final bool comparator;
  final Widget child;
  const PremiumBannerFollowingFeed({
    super.key,
    required this.comparator,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return comparator
        ? child
        : Stack(
            children: <Widget>[
              child,
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(25), bottomRight: Radius.circular(25))),
                  padding: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}
