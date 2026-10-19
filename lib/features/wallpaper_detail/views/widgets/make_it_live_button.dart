import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/l10n/l10n.dart';
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
    return PrismButton(
      label: context.l10n.wallpaperMakeItLive,
      icon: Icons.motion_photos_on_outlined,
      variant: PrismButtonVariant.tonal,
      size: PrismButtonSize.compact,
      onPressed: widget.onPressed,
    );
  }
}

/// Small "Live" pill over the wallpaper, on a dark glass scrim like the other controls on the image. It opens Make it
/// live and appears only when the device can run it.
class MakeItLiveChip extends StatefulWidget {
  const MakeItLiveChip({required this.onPressed, this.supportProbe = _deviceSupportsOpenGlLive, super.key});

  /// Height and minimum width of the touch target.
  static const double hitSize = 48;

  /// Height of the glass pill inside the touch target.
  static const double pillHeight = 32;

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
    final Widget chip = Semantics(
      button: true,
      label: context.l10n.wallpaperMakeItLive,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: PressScale(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: MakeItLiveChip.hitSize, minHeight: MakeItLiveChip.hitSize),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: SizedBox(
                height: MakeItLiveChip.pillHeight,
                child: PrismGlass(
                  borderRadius: MakeItLiveChip.pillHeight / 2,
                  thickness: 16,
                  glassColor: Colors.black.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.motion_photos_on_outlined, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.wallpaperLive,
                          style: PrismTextStyles.caption(
                            context,
                          ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: context.motion(const Duration(milliseconds: 160)),
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) => Opacity(opacity: opacity, child: child),
      child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: chip),
    );
  }
}
