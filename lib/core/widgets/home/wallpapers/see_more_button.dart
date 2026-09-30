import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:flutter/material.dart';

class SeeMoreButton extends StatelessWidget {
  const SeeMoreButton({super.key, required this.seeMoreLoader, required this.func});

  final bool seeMoreLoader;
  final VoidCallback func;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: context.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: .1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        func();
      },
      child: !seeMoreLoader ? const Text("See more") : Loader(),
    );
  }
}
