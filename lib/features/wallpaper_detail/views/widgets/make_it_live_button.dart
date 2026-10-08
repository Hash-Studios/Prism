import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/material.dart';

Future<bool> _deviceSupportsOpenGlLive() async =>
    (await aw.AsyncWallpaper.getCapabilities()).supportsOpenGlLiveWallpaper;

/// "Make it live" action. It appears only when the device can run an OpenGL live wallpaper.
class MakeItLiveButton extends StatefulWidget {
  const MakeItLiveButton({required this.onPressed, this.supportProbe = _deviceSupportsOpenGlLive, super.key});

  final VoidCallback onPressed;
  final Future<bool> Function() supportProbe;

  @override
  State<MakeItLiveButton> createState() => _MakeItLiveButtonState();
}

class _MakeItLiveButtonState extends State<MakeItLiveButton> {
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    bool supported;
    try {
      supported = await widget.supportProbe();
    } catch (_) {
      supported = false;
    }
    if (supported && mounted) setState(() => _supported = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: widget.onPressed,
      icon: const Icon(Icons.motion_photos_on_outlined, size: 20),
      label: const Text('Make it live'),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.secondary,
        side: BorderSide(color: scheme.secondary.withValues(alpha: 0.4)),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// Small "Live" chip over the wallpaper. It opens Make it live and appears only when the device can run it.
class MakeItLiveChip extends StatefulWidget {
  const MakeItLiveChip({required this.onPressed, this.supportProbe = _deviceSupportsOpenGlLive, super.key});

  final VoidCallback onPressed;
  final Future<bool> Function() supportProbe;

  @override
  State<MakeItLiveChip> createState() => _MakeItLiveChipState();
}

class _MakeItLiveChipState extends State<MakeItLiveChip> {
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    bool supported;
    try {
      supported = await widget.supportProbe();
    } catch (_) {
      supported = false;
    }
    if (supported && mounted) setState(() => _supported = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Make it live',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.motion_photos_on_outlined, size: 16, color: scheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Live',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.bold,
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
  }
}
