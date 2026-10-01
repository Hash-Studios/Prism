import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:flutter/material.dart';

class SeeMoreButton extends StatelessWidget {
  const SeeMoreButton({super.key, required this.seeMoreLoader, required this.func});

  final bool seeMoreLoader;
  final VoidCallback func;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: context.isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: .1),
      shape: const RoundedRectangleBorder(),
      onPressed: () {
        PrismHaptics.tap();
        func();
      },
      child: AnimatedSwitcher(
        duration: context.motion(PrismDurations.fast),
        child: !seeMoreLoader
            ? const Text("See more", key: ValueKey('label'))
            : const SizedBox.square(
                key: ValueKey('loading'),
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }
}
