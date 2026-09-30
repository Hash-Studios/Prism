import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

enum PrismToastKind { success, error, plain }

OverlayEntry? _current;

/// Shows one short message in a pill above the bottom bar. A new toast replaces the one on screen.
void showPrismToast(OverlayState overlay, String message, {PrismToastKind kind = PrismToastKind.plain, Color? color}) {
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PrismToast(
      message: message,
      kind: kind,
      color: color,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _PrismToast extends StatefulWidget {
  const _PrismToast({required this.message, required this.kind, required this.onDone, this.color});

  final String message;
  final PrismToastKind kind;
  final Color? color;
  final VoidCallback onDone;

  @override
  State<_PrismToast> createState() => _PrismToastState();
}

class _PrismToastState extends State<_PrismToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PrismDurations.base,
    reverseDuration: PrismDurations.fast,
  );
  late final CurvedAnimation _curve = CurvedAnimation(parent: _controller, curve: PrismCurves.enter);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // Errors stay longer: the user has to read what went wrong.
    final int ms = widget.kind == PrismToastKind.error ? 3600 : 2400;
    _timer = Timer(Duration(milliseconds: ms + widget.message.length * 20), _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final MediaQueryData mq = MediaQuery.of(context);
    final Color bg = widget.color ?? cs.inverseSurface;
    final Color fg = widget.color == null
        ? cs.onInverseSurface
        : (bg.computeLuminance() > 0.5 ? Colors.black : Colors.white);
    final (IconData? icon, Color iconColor) = switch (widget.kind) {
      PrismToastKind.success => (Icons.check_circle_rounded, fg),
      PrismToastKind.error => (Icons.error_rounded, fg),
      PrismToastKind.plain => (null, fg),
    };
    final bool reduce = context.reduceMotion;
    return Positioned(
      left: PrismSpace.page,
      right: PrismSpace.page,
      bottom: mq.viewPadding.bottom + mq.viewInsets.bottom + 92,
      child: Center(
        child: FadeTransition(
          opacity: _curve,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, reduce ? 0 : 12 * (1 - _curve.value)), child: child),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: GestureDetector(
                onTap: _dismiss,
                child: Material(
                  color: bg,
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (icon != null) ...<Widget>[
                            Icon(icon, size: 18, color: iconColor),
                            const SizedBox(width: PrismSpace.xs),
                          ],
                          Flexible(
                            child: Text(
                              widget.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: PrismFonts.proximaNova,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: fg,
                                decoration: TextDecoration.none,
                              ),
                            ),
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
      ),
    );
  }
}
