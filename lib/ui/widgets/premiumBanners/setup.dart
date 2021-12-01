import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class PremiumBannerSetup extends StatelessWidget {
  final bool? comparator;
  final Widget? child;
  const PremiumBannerSetup({this.comparator, this.child});
  @override
  Widget build(BuildContext context) {
    return comparator!
        ? child!
        : Stack(
            children: [
              child,
              Positioned(
                top: MediaQuery.of(context).size.height * 0.62 - 32,
                left: MediaQuery.of(context).size.width * 0.642 - 15,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(10))),
                  padding: const EdgeInsets.all(0),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Icon(
                      JamIcons.star_f,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ] as List<Widget>,
          );
  }
}
