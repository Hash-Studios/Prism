import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A gesture the app teaches once, in place, on real content.
enum GestureHint {
  /// Long-press a wallpaper tile for quick actions.
  holdToSave,

  /// Swipe up on the wallpaper detail for similar walls.
  swipeForSimilar;

  String get _settingsKey => 'gestureHintSeen.$name';
}

/// Remembers which gesture hints the user has already used. A hint shows until its gesture is used once, then never
/// again. Without local settings (tests, early startup) no hint shows.
abstract final class GestureHints {
  static final Map<GestureHint, ValueNotifier<bool>> _seen = <GestureHint, ValueNotifier<bool>>{};

  static ValueNotifier<bool> seen(GestureHint hint) => _seen.putIfAbsent(hint, () {
    bool value = true;
    if (getIt.isRegistered<SettingsLocalDataSource>()) {
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      if (settings.isOpen) value = settings.get<bool>(hint._settingsKey, defaultValue: false);
    }
    return ValueNotifier<bool>(value);
  });

  /// Call when the user performs the gesture.
  static void markSeen(GestureHint hint) {
    final ValueNotifier<bool> notifier = seen(hint);
    if (notifier.value) return;
    notifier.value = true;
    if (getIt.isRegistered<SettingsLocalDataSource>()) {
      getIt<SettingsLocalDataSource>().set(hint._settingsKey, true);
    }
  }

  @visibleForTesting
  static void resetForTest() => _seen.clear();
}

/// A one-time hint drawn over an image: a hand glyph and a few words on a soft dark scrim. It fades in after [delay]
/// and fades out for good once [GestureHints.markSeen] is called for [hint]. Place it in the image's [Stack].
class GestureHintOverlay extends StatefulWidget {
  const GestureHintOverlay({
    super.key,
    required this.hint,
    required this.label,
    this.icon = Icons.touch_app_rounded,
    this.delay = const Duration(milliseconds: 600),
    this.scrim = true,
  });

  final GestureHint hint;
  final String label;
  final IconData icon;
  final Duration delay;

  /// Darken the image under the hint. Off for a hint over a large, busy hero where a scrim would hide the content.
  final bool scrim;

  @override
  State<GestureHintOverlay> createState() => _GestureHintOverlayState();
}

class _GestureHintOverlayState extends State<GestureHintOverlay> {
  bool _shown = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () => setState(() => _shown = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GestureHints.seen(widget.hint),
      builder: (context, seen, _) {
        final bool visible = _shown && !seen;
        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: context.motion(PrismDurations.base),
            curve: PrismCurves.enter,
            child: seen && !_shown
                ? const SizedBox.shrink()
                : DecoratedBox(
                    decoration: BoxDecoration(color: widget.scrim ? Colors.black.withValues(alpha: 0.42) : null),
                    child: Center(
                      child: Semantics(
                        label: widget.label,
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 28,
                                shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 12)],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: PrismTextStyles.body(context).copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 10)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
