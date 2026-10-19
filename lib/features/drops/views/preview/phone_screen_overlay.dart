import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Which phone screen the preview mocks over the wall.
enum DropPreviewMode { lockScreen, homeScreen }

/// A lock screen or home screen mock, drawn over a wall so it reads at phone scale.
class PhoneScreenOverlay extends StatelessWidget {
  const PhoneScreenOverlay({super.key, required this.mode, required this.now});

  final DropPreviewMode mode;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final Widget screen = switch (mode) {
          DropPreviewMode.lockScreen => _LockScreen(width: w, now: now),
          DropPreviewMode.homeScreen => _HomeScreen(width: w),
        };
        return IgnorePointer(
          child: ExcludeSemantics(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey<DropPreviewMode>(mode), child: screen),
            ),
          ),
        );
      },
    );
  }
}

List<Shadow> _lift(double w) => <Shadow>[
  Shadow(color: DropPalette.obsidian.withValues(alpha: 0.45), blurRadius: w * 0.05),
];

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.width, required this.now});

  final double width;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                DropPalette.obsidian.withValues(alpha: 0.38),
                DropPalette.obsidian.withValues(alpha: 0),
                DropPalette.obsidian.withValues(alpha: 0),
                DropPalette.obsidian.withValues(alpha: 0.3),
              ],
              stops: const <double>[0, 0.3, 0.75, 1],
            ),
          ),
        ),
        Positioned(
          top: width * 0.2,
          left: 0,
          right: 0,
          child: Column(
            children: <Widget>[
              Text(
                DateFormat('EEEE, d MMMM').format(now),
                style: TextStyle(
                  color: DropPalette.ink.withValues(alpha: 0.9),
                  fontSize: width * 0.052,
                  fontWeight: FontWeight.w600,
                  shadows: _lift(width),
                ),
              ),
              Text(
                DateFormat('H:mm').format(now),
                style: TextStyle(
                  fontFamily: PrismFonts.fraunces,
                  color: DropPalette.ink,
                  fontSize: width * 0.3,
                  height: 1.05,
                  fontVariations: const <FontVariation>[FontVariation('wght', 200), FontVariation('opsz', 144)],
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  shadows: _lift(width),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: width * 0.1,
          right: width * 0.1,
          bottom: width * 0.12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _Frosted(size: width * 0.14, radius: width * 0.07),
              _Frosted(size: width * 0.14, radius: width * 0.07),
            ],
          ),
        ),
        Positioned(
          bottom: width * 0.03,
          left: width * 0.34,
          right: width * 0.34,
          child: _HomeBar(width: width),
        ),
      ],
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final double icon = width * 0.17;
    final double gap = (width * 0.8 - icon * 4) / 3;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          top: width * 0.26,
          left: width * 0.1,
          right: width * 0.1,
          child: Column(
            children: <Widget>[
              for (int row = 0; row < 3; row++)
                Padding(
                  padding: EdgeInsets.only(bottom: width * 0.1),
                  child: Row(
                    children: <Widget>[
                      if (row == 0) ...<Widget>[
                        _Frosted(size: icon * 2 + gap, height: icon, radius: icon * 0.26),
                        SizedBox(width: gap),
                        _Frosted(size: icon, radius: icon * 0.26),
                        SizedBox(width: gap),
                        _Frosted(size: icon, radius: icon * 0.26),
                      ] else
                        for (int col = 0; col < 4; col++) ...<Widget>[
                          if (col > 0) SizedBox(width: gap),
                          _Frosted(size: icon, radius: icon * 0.26),
                        ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: width * 0.06,
          right: width * 0.06,
          bottom: width * 0.1,
          child: _Frosted(size: width * 0.88, height: icon * 1.25, radius: icon * 0.42),
        ),
        Positioned(
          bottom: width * 0.03,
          left: width * 0.34,
          right: width * 0.34,
          child: _HomeBar(width: width),
        ),
      ],
    );
  }
}

class _Frosted extends StatelessWidget {
  const _Frosted({required this.size, required this.radius, this.height});

  final double size;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: DropPalette.ink.withValues(alpha: 0.16),
        border: Border.all(color: DropPalette.ink.withValues(alpha: 0.22), width: 0.6),
      ),
      child: SizedBox(width: size, height: height ?? size),
    );
  }
}

class _HomeBar extends StatelessWidget {
  const _HomeBar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width),
        color: DropPalette.ink.withValues(alpha: 0.75),
      ),
      child: SizedBox(height: width * 0.014),
    );
  }
}
