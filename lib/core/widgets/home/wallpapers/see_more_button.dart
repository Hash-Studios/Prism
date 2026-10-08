import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:flutter/material.dart';

class SeeMoreButton extends StatelessWidget {
  const SeeMoreButton({super.key, required this.seeMoreLoader, required this.func, this.failed = false});

  final bool seeMoreLoader;

  /// The last page failed to load; the label asks for a retry.
  final bool failed;
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
            ? Text(
                failed ? "Couldn't load more. Tap to retry" : 'See more',
                key: ValueKey(failed ? 'retry' : 'label'),
                textAlign: TextAlign.center,
              )
            : const SizedBox.square(
                key: ValueKey('loading'),
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }
}
