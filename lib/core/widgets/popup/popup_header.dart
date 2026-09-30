import 'package:flutter/material.dart';

class PopupHeader extends StatelessWidget {
  const PopupHeader({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: width,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
        color: Theme.of(context).hintColor,
      ),
      child: child,
    );
  }
}
