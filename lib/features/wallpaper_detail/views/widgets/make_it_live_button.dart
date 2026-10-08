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
